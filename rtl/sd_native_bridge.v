// Read-only SDHC/SDXC native 4-bit host. Default-speed 3.3V /25MHz.
// Existing one-sector CDC contract is retained; no extra block RAM.
module sd_native_bridge(input wire clk,sd_clk,rst,
 inout wire SD_nCS,SD_MOSI,output wire SD_DCLK,input wire SD_MISO,SD_D1,SD_D2,
 output reg sd_init_done,input wire sd_sec_read,read_stream,input wire[31:0]sd_sec_read_addr,
 output reg[7:0]sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
 input wire sd_sec_write,input wire[31:0]sd_sec_write_addr,input wire[7:0]sd_sec_write_data,
 output wire sd_sec_write_data_req,sd_sec_write_end);
 assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 reg[2:0]reset_pipe;always @(posedge sd_clk or posedge rst)if(rst)reset_pipe<=7;else reset_pipe<={reset_pipe[1:0],1'b0};
 wire srst=reset_pipe[2];
 reg request_toggle,busy,held_stream;reg[31:0]held_address;
 reg request_meta,request_sync,request_seen,request_pulse;
 wire native_ready,native_valid,native_end;wire[7:0]native_data;
 reg byte_toggle,end_toggle;reg[7:0]byte_hold;
 reg byte_meta,byte_sync,byte_seen,end_meta,end_sync,end_seen,ready_meta;
 always @(posedge sd_clk or posedge srst)begin
  if(srst)begin request_meta<=0;request_sync<=0;request_seen<=0;request_pulse<=0;byte_toggle<=0;end_toggle<=0;byte_hold<=0;end
  else begin
   request_meta<=request_toggle;request_sync<=request_meta;request_pulse<=0;
   if(request_sync!=request_seen)begin request_seen<=request_sync;request_pulse<=1;end
   if(native_valid)begin byte_hold<=native_data;byte_toggle<=~byte_toggle;end
   if(native_end)end_toggle<=~end_toggle;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin request_toggle<=0;busy<=0;held_address<=0;held_stream<=1;byte_meta<=0;byte_sync<=0;byte_seen<=0;end_meta<=0;end_sync<=0;end_seen<=0;ready_meta<=0;sd_init_done<=0;sd_sec_read_data<=0;sd_sec_read_data_valid<=0;sd_sec_read_end<=0;end
  else begin
   ready_meta<=native_ready;sd_init_done<=ready_meta;byte_meta<=byte_toggle;byte_sync<=byte_meta;end_meta<=end_toggle;end_sync<=end_meta;
   sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
   if(sd_sec_read && !busy && sd_init_done)begin held_address<=sd_sec_read_addr;held_stream<=read_stream;request_toggle<=~request_toggle;busy<=1;end
   if(byte_sync!=byte_seen)begin byte_seen<=byte_sync;if(busy)begin sd_sec_read_data<=byte_hold;sd_sec_read_data_valid<=1;end end
   if(end_sync!=end_seen)begin end_seen<=end_sync;if(busy)begin sd_sec_read_end<=1;busy<=0;end end
  end
 end
 sd_native_host core(sd_clk,srst,SD_DCLK,SD_MOSI,{SD_nCS,SD_D2,SD_D1,SD_MISO},native_ready,
  request_pulse,held_stream,held_address,native_data,native_valid,native_end);
 // DAT3 is an input in this read-only host, including during CMD0. Never
 // drive it low: native mode must not accidentally enter SPI mode.
 assign SD_nCS=1'bz;
endmodule

module sd_native_host(input wire clk,rst,output reg sck,inout wire cmd,input wire[3:0]dat,
 output reg ready,input wire request,stream,input wire[31:0]address,
 output reg[7:0]byte_data,output reg byte_valid,sector_end);
 localparam BOOT=0,C_GAP=1,C_START=2,C_TX=3,C_RELEASE=4,C_WAIT=5,C_RESP=6,C_DONE=7,
  BUSY_WAIT=8,SPEED_WAIT=9,IDLE=10,TOKEN=11,DATA=12,CRC=13,END_BIT=14,FLUSH=15,FAULT=16;
 reg[4:0]state;reg[3:0]step,busy_guard,flush;
 reg desired_fast,fast_mode,running,sample_tick;
 reg[6:0]divider;wire[6:0]half_limit=fast_mode?7'd1:7'd124;
 wire want_clock=state!=IDLE && state!=FAULT && state!=SPEED_WAIT && state!=FLUSH;
 wire rise_tick=running && divider==half_limit && !sck;
 wire fall_tick=running && divider==half_limit && sck;
 always @(posedge clk or posedge rst)begin
  if(rst)begin sck<=0;divider<=0;running<=0;fast_mode<=0;sample_tick<=0;end
  else begin
   sample_tick<=rise_tick;
   if(!running)begin sck<=0;divider<=0;fast_mode<=desired_fast;if(want_clock && fast_mode==desired_fast)running<=1;end
   else if(divider==half_limit)begin divider<=0;sck<=~sck;if(sck && !want_clock)running<=0;end
   else divider<=divider+1'b1;
  end
 end
 reg cmd_oe,cmd_out;assign cmd=cmd_oe?cmd_out:1'bz;
 reg[7:0]tx_frame;reg[5:0]command_no;reg[6:0]tx_crc,rx_crc;
 reg[5:0]bit_pos;reg[7:0]resp_pos,resp_length,wait_clocks;reg response_bad,r3;
 reg[31:0]response_arg;reg[15:0]rca;reg[11:0]attempts;
 reg[6:0]boot_clocks;reg[3:0]gap_clocks;
 reg stream_active;reg[31:0]stream_next;
 reg[24:0]timeout;
 reg half_byte;reg[3:0]upper;reg[8:0]byte_index;reg[7:0]last_byte;
 reg[15:0]crc0,crc1,crc2,crc3;reg[3:0]crc_pos;reg data_bad;
 function[6:0]c7;input[6:0]c;input b;begin c7={c[5:0],1'b0}^((c[6]^b)?7'h09:7'd0);end endfunction
 function[15:0]c16;input[15:0]c;input b;begin c16={c[14:0],1'b0}^((c[15]^b)?16'h1021:16'd0);end endfunction
 // Emit arguments one byte at a time. The request address stays bundled
 // until completion; RCA is retained after CMD3. This replaces the wide
 // command-argument mux and 40-bit shifter without changing bus timing.
 reg[7:0]argument_byte;
 always @*begin
  argument_byte=0;
  case(command_no)
   17,18:case(bit_pos[4:3])
    0:argument_byte=address[31:24];1:argument_byte=address[23:16];
    2:argument_byte=address[15:8];3:argument_byte=address[7:0];endcase
   7,55:case(bit_pos[4:3])0:argument_byte=rca[15:8];1:argument_byte=rca[7:0];endcase
   8:case(bit_pos[4:3])2:argument_byte=1;3:argument_byte=8'haa;endcase
   41:case(bit_pos[4:3])0:argument_byte=8'h40;1:argument_byte=8'hff;2:argument_byte=8'h80;endcase
   16:if(bit_pos[4:3]==2)argument_byte=2;
   6:if(bit_pos[4:3]==3)argument_byte=2;
  endcase
 end
 wire tx_bit=bit_pos<40?tx_frame[7]:bit_pos<47?tx_crc[6]:1'b1;
 task issue;input[5:0]n;input[31:0]a;input[3:0]st;begin
  tx_frame<={2'b01,n};command_no<=n;step<=st;tx_crc<=0;bit_pos<=0;
  resp_length<=n==2?136:48;r3<=n==41;gap_clocks<=0;cmd_oe<=0;cmd_out<=1;state<=C_GAP;
 end endtask
 task fault;begin ready<=0;state<=FAULT;timeout<=0;cmd_oe<=0;stream_active<=0;desired_fast<=0;rca<=0;end endtask
 task start_data;begin state<=TOKEN;timeout<=0;byte_index<=0;half_byte<=0;data_bad<=0;end endtask
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=BOOT;step<=0;busy_guard<=0;flush<=0;desired_fast<=0;ready<=0;byte_data<=0;byte_valid<=0;sector_end<=0;
   cmd_oe<=0;cmd_out<=1;tx_frame<=0;command_no<=0;tx_crc<=0;rx_crc<=0;bit_pos<=0;resp_pos<=0;resp_length<=48;wait_clocks<=0;response_bad<=0;r3<=0;response_arg<=0;
   rca<=0;attempts<=0;boot_clocks<=0;gap_clocks<=0;stream_active<=0;stream_next<=0;timeout<=0;
   half_byte<=0;upper<=0;byte_index<=0;last_byte<=0;crc0<=0;crc1<=0;crc2<=0;crc3<=0;crc_pos<=0;data_bad<=0;
  end else begin
   byte_valid<=0;sector_end<=0;
   if(state==TOKEN || state==BUSY_WAIT)timeout<=timeout+1'b1;
   case(state)
    // Allow card supply to settle before issuing the initialization sequence.
    // Clocks remain at 400 kHz; after the 2 ms guard, count another 80 clocks.
    BOOT:if(timeout<25'd200000)timeout<=timeout+1'b1;
      else if(sample_tick)begin if(boot_clocks==79)issue(0,0,0);else boot_clocks<=boot_clocks+1'b1;end
    C_GAP:if(sample_tick)begin if(gap_clocks==7)state<=C_START;else gap_clocks<=gap_clocks+1'b1;end
    C_START:if(fall_tick)begin cmd_oe<=1;cmd_out<=0;bit_pos<=0;state<=C_TX;end
    C_TX:begin
     if(fall_tick)cmd_out<=tx_bit;
     if(sample_tick)begin
      if(bit_pos<40)begin tx_crc<=c7(tx_crc,tx_frame[7]);if(bit_pos[2:0]==7)tx_frame<=argument_byte;else tx_frame<={tx_frame[6:0],1'b1};end
      else if(bit_pos<47)tx_crc<={tx_crc[5:0],1'b0};
      if(bit_pos==47)state<=C_RELEASE;else bit_pos<=bit_pos+1'b1;
     end
    end
    C_RELEASE:if(fall_tick)begin cmd_oe<=0;wait_clocks<=0;state<=command_no==0?C_DONE:C_WAIT;end
    C_WAIT:if(sample_tick)begin
     if(cmd===1'b0)begin resp_pos<=1;rx_crc<=0;response_arg<=0;response_bad<=0;state<=C_RESP;end
     else if(wait_clocks==127)fault();else wait_clocks<=wait_clocks+1'b1;
    end
    C_RESP:if(sample_tick)begin
     if(resp_pos<40)rx_crc<=c7(rx_crc,cmd);
     if(resp_length==48)begin
      if(resp_pos==1 && cmd!=0)response_bad<=1;
      if(!r3 && resp_pos>=2 && resp_pos<8 && cmd!=command_no[7-resp_pos])response_bad<=1;
      if(resp_pos>=8 && resp_pos<40)response_arg<={response_arg[30:0],cmd};
      if(!r3 && resp_pos>=40 && resp_pos<47)begin
       if(cmd!=rx_crc[6])response_bad<=1;rx_crc<={rx_crc[5:0],1'b0};
      end
     end
     if(resp_pos==resp_length-1)begin if(cmd!=1)response_bad<=1;state<=C_DONE;end
     else resp_pos<=resp_pos+1'b1;
    end
    C_DONE:begin
     if(command_no!=0 && response_bad)fault();
     else if(command_no!=0 && command_no!=2 && command_no!=3 && command_no!=8 && command_no!=41 && (response_arg&32'hfff98008)!=0)fault();
     else case(step)
      0:issue(8,32'h1aa,1);
      1:if(response_arg[11:0]!=12'h1aa)fault();else issue(55,0,2);
      2:issue(41,32'h40ff8000,3);
      3:if(response_arg[31])begin if(!response_arg[30])fault();else issue(2,0,4);end
        else if(attempts==4095)fault();else begin attempts<=attempts+1'b1;issue(55,0,2);end
      4:issue(3,0,5);
      5:if(response_arg[31:16]==0 || (response_arg[15:0]&16'he000)!=0)fault();
        else begin rca<=response_arg[31:16];issue(7,{response_arg[31:16],16'd0},6);end
      6:begin busy_guard<=0;timeout<=0;state<=BUSY_WAIT;end
      7:issue(55,{rca,16'd0},8);
      8:issue(6,2,9);
      9:begin desired_fast<=1;state<=SPEED_WAIT;end
      10:begin stream_active<=stream;stream_next<=address+1'b1;start_data();end
      11:begin stream_active<=0;busy_guard<=0;timeout<=0;state<=BUSY_WAIT;end
      default:fault();
     endcase
    end
    BUSY_WAIT:begin
     if(timeout==25'd20000000)fault();
     else if(sample_tick)begin
      if(busy_guard!=8)busy_guard<=busy_guard+1'b1;
      else if(dat[0])begin if(step==6)issue(16,512,7);else issue(stream?18:17,address,10);end
     end
    end
    SPEED_WAIT:if(!running && fast_mode)begin ready<=1;state<=IDLE;end
    IDLE:if(request && ready)begin
     if(stream_active && stream && address==stream_next)begin stream_next<=stream_next+1'b1;start_data();end
     else if(stream_active)issue(12,0,11);
     else issue(stream?18:17,address,10);
    end
    TOKEN:begin
     if(timeout==25'd20000000)fault();
     else if(sample_tick && dat==0)begin crc0<=0;crc1<=0;crc2<=0;crc3<=0;byte_index<=0;half_byte<=0;state<=DATA;end
    end
    DATA:if(sample_tick)begin
     crc0<=c16(crc0,dat[0]);crc1<=c16(crc1,dat[1]);crc2<=c16(crc2,dat[2]);crc3<=c16(crc3,dat[3]);
     half_byte<=~half_byte;
     if(!half_byte)upper<=dat;
     else if(byte_index==511)begin last_byte<={upper,dat};crc_pos<=0;data_bad<=0;state<=CRC;end
     else begin byte_data<={upper,dat};byte_valid<=1;byte_index<=byte_index+1'b1;end
    end
    CRC:if(sample_tick)begin
     if(dat!={crc3[15],crc2[15],crc1[15],crc0[15]})data_bad<=1;
     crc0<={crc0[14:0],1'b0};crc1<={crc1[14:0],1'b0};crc2<={crc2[14:0],1'b0};crc3<={crc3[14:0],1'b0};
     if(crc_pos==15)state<=END_BIT;else crc_pos<=crc_pos+1'b1;
    end
    END_BIT:if(sample_tick)begin
     // Withhold the final byte on a bad CRC. The upper sector parser will
     // reject the short block even if its timeout synthesizes an end event.
     if(dat!=15 || data_bad)fault();
     else begin byte_data<=last_byte;byte_valid<=1;flush<=8;state<=FLUSH;end
    end
    FLUSH:if(flush!=0)flush<=flush-1'b1;else begin sector_end<=1;state<=IDLE;end
    FAULT:if(timeout==25'd10000000)begin timeout<=0;boot_clocks<=0;attempts<=0;state<=BOOT;end else timeout<=timeout+1'b1;
    default:fault();
   endcase
  end
 end
endmodule
