`timescale 1ns/1ps
module tb_sdhs30;
 reg clk=0,rst=1,req=0,stream=0;always #7.5 clk=~clk;
 reg sdclk=0;initial begin #2.5;forever #5 sdclk=~sdclk;end
 reg[31:0] lba=0;wire cs,sck,mosi,ready,bv,done;wire[7:0]bd;
 reg miso=1;integer bitno=0,cmdpos=0,resp_pos=0,resp_len=0;
 reg[7:0]rx=0,tx=255,cb[0:5],response[0:15];
 integer block_len=512;reg hs_status=0,hs_card=0;reg reject_hs=0;initial reject_hs=$test$plusargs("NO_HS");
 integer card_stage=0,token_left=0,data_index=0,card_lba=0;
 integer cmd17s=0,cmd18s=0,cmd12s=0,received=0,expected_lba=0,cycles=0,started=0,elapsed=0;
 integer first_token=700,next_token=3;reg multi=0,idle_card=1;
 sd_read_bridge dut(.sd_clk(sdclk),
 .clk(clk),.rst(rst),.SD_nCS(cs),.SD_DCLK(sck),.SD_MOSI(mosi),.SD_MISO(miso),
 .sd_init_done(ready),.sd_sec_read(req),.read_stream(stream),.sd_sec_read_addr(lba),
 .sd_sec_read_data(bd),.sd_sec_read_data_valid(bv),.sd_sec_read_end(done),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
 function[7:0] datum;input integer blockno,offset;begin datum=((blockno*17+offset)^90)&255;end endfunction
 task process_command;
  integer id,arg;
  begin
   id=cb[0]&63;arg={cb[1],cb[2],cb[3],cb[4]};$display("CMD %0d arg=%h",id,arg);
   resp_pos=0;resp_len=1;response[0]=idle_card?1:0;
   case(id)
    0:begin idle_card=1;response[0]=1;multi=0;card_stage=0;hs_card=0;hs_status=0;end
    8:begin resp_len=5;response[0]=1;response[1]=0;response[2]=0;response[3]=1;response[4]=170;end
    55:begin end
    41:begin idle_card=0;response[0]=0;end
    16:begin if(arg!=512)$fatal(1,"CMD16 size");end
    6:begin
     if(arg!=32'h80fffff1 || multi)$fatal(1,"CMD6 switch argument/state");
     hs_status=1;block_len=64;card_stage=1;token_left=3;data_index=0;
    end
    13:begin if(!hs_card)$fatal(1,"CMD13 before switch status");resp_len=2;response[0]=0;response[1]=0;end
    17,18:begin
     if(multi)$fatal(1,"new read before CMD12");
     if(!hs_card)$fatal(1,"read before high-speed negotiation");hs_status=0;block_len=512;
     multi=id==18;card_lba=arg;card_stage=1;token_left=first_token;data_index=0;
     if(id==17)cmd17s=cmd17s+1;else cmd18s=cmd18s+1;
    end
    12:begin
     if(!multi)$fatal(1,"unexpected stop");
     multi=0;card_stage=0;cmd12s=cmd12s+1;
     // A misleading stuff byte must be ignored, followed by R1b busy.
     resp_len=5;response[0]=8'h04;response[1]=0;response[2]=0;response[3]=0;response[4]=255;
    end
    default:$fatal(1,"unexpected command %0d",id);
   endcase
  end
 endtask
 task next_output;
  begin
   if(resp_pos<resp_len)begin tx=response[resp_pos];resp_pos=resp_pos+1;end
   else case(card_stage)
    1:if(token_left>0)begin tx=255;token_left=token_left-1;end
      else begin tx=254;card_stage=2;data_index=0;end
    2:begin tx=hs_status?(data_index==16?(reject_hs?8'h0f:8'h01):8'h00):datum(card_lba,data_index);data_index=data_index+1;if(data_index==block_len)card_stage=3;end
    3:begin tx=255;card_stage=4;end
    4:begin tx=255;if(hs_status && !reject_hs)hs_card=1;if(multi)begin card_stage=1;token_left=next_token;card_lba=card_lba+1;end else card_stage=0;end
    default:tx=255;
   endcase
  end
 endtask
 always @(posedge cs)begin
  if(multi && !rst)$fatal(1,"CS released before CMD12");
  bitno=0;cmdpos=0;resp_len=0;resp_pos=0;tx=255;miso=1;
 end
 always @(negedge sck)if(!cs)miso <= #16 tx[7-bitno];
 always @(posedge sck)if(!cs)begin
  rx={rx[6:0],mosi};
  if(bitno==7)begin
   bitno=0;
   if(cmdpos!=0 || rx[7:6]==2'b01)begin
    cb[cmdpos]=rx;cmdpos=cmdpos+1;
    if(cmdpos==6)begin process_command();cmdpos=0;end
   end
   next_output();
  end else bitno=bitno+1;
 end
 always @(posedge clk)begin
  cycles=cycles+1;
  if(bv)begin
   if(bd!==datum(expected_lba,received))$fatal(1,"read LBA=%0d offset=%0d got=%h expected=%h",expected_lba,received,bd,datum(expected_lba,received));
   received=received+1;
  end
 end
 task read_block;input integer address;
  begin
   @(negedge clk);lba=address;expected_lba=address;received=0;req=1;
   @(negedge clk);req=0;
   wait(done);@(negedge clk);if(received!=512)$fatal(1,"sector length %0d",received);
   repeat(18)@(negedge clk);
  end
 endtask
 time last_edge=0;
 always @(sck)begin if(rst)last_edge=0;else begin if(last_edge!=0 && $time-last_edge<10)$fatal(1,"SPI half-cycle shorter than 10 ns");last_edge=$time;end end
 integer i;real rate;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  if($test$plusargs("NO_HS"))begin
   wait(dut.core.sd_card_sec_read_write_m0.state==14);repeat(4)@(negedge clk);
   if(ready || dut.core.sd_card_sec_read_write_m0.spi_clk_div==16'hffff)$fatal(1,"unsupported card entered high speed");
   $display("PASS unsupported high-speed function rejected without raising SCK");$finish;
  end
  wait(ready);repeat(10)@(negedge clk);
  // Legacy, then consecutive video blocks, fragmented seek, and back to legacy.
  stream=0;read_block(50);read_block(51);
  stream=1;read_block(100);started=cycles;
  for(i=101;i<133;i=i+1)read_block(i);
  elapsed=cycles-started;rate=32.0*512*1e9/(elapsed*15);
  $display("MULTIREAD effective_Bps=%0f consecutive_clocks=%0d CMD17=%0d CMD18=%0d CMD12=%0d",rate,elapsed,cmd17s,cmd18s,cmd12s);
  if(rate<4200000)$fatal(1,"insufficient streaming throughput");
  read_block(900);read_block(901);read_block(0);read_block(1);
  stream=0;read_block(70);read_block(71);
  if(cmd18s!=3 || cmd12s!=3 || cmd17s!=4)$fatal(1,"command counts %0d %0d %0d",cmd17s,cmd18s,cmd12s);
  stream=1;read_block(500);
  @(negedge clk);lba=501;expected_lba=501;received=0;req=1;
  @(negedge clk);req=0;
  wait(received>=37);@(negedge clk);rst=1;
  repeat(5)@(negedge clk);rst=0;wait(ready);repeat(10)@(negedge clk);
  stream=0;read_block(77);
  $display("PASS line-level SD init, single/multi sectors, CMD12 stuff/busy, fragmented seeks, media mode switch, mid-sector reset recovery and exact bytes");$finish;
 end
 initial begin #30000000;$fatal(1,"deadline sec=%0d cmd=%0d received=%0d",dut.core.sd_card_sec_read_write_m0.state,dut.core.sd_card_cmd_m0.state,received);end
endmodule


