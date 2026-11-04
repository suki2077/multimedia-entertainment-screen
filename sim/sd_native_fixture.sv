`timescale 1ns/1ps
module sd_native_fixture #(parameter DISK=0,FOLDER="sim/fixtures/video/partition")(input wire power_rst,sck,inout wire cmd,output reg[3:0]dat,
 input wire bad_crc,bad_response);
 reg drive=0,value=1;assign cmd=drive?value:1'bz;
 reg[47:0]capture=0;integer captured=0;
 reg[135:0]response;integer response_len=48,response_pos=0,response_delay=0;
 reg pending=0,sending=0;integer after_busy=0,busy=0,after_read=0;
 integer stage=0,delay_count=0,offset=0,crc_index=0,lba=0;
 reg multi=0,app=0,selected=0,wide=0;integer acmd41=0,cmd17s=0,cmd18s=0,cmd12s=0,commands=0;
 reg[15:0]crc_ref[0:8191];
 reg[31:0]info[0:2],lbas[0:2047];reg[7:0]disk[0:1048575];integer count=0,card_index=-1;
 function integer locate;input integer address;integer k;begin locate=-1;for(k=0;k<count;k=k+1)if(lbas[k]==address)locate=k;end endfunction
 function[7:0]datum;input integer blockno,bytepos;begin datum=DISK?(card_index<0?255:disk[card_index*512+bytepos]):((blockno*17+bytepos)^90)&255;end endfunction
 function[6:0]crc7;input[39:0]bits;integer j;reg[6:0]c;begin c=0;for(j=39;j>=0;j=j-1)c={c[5:0],1'b0}^((c[6]^bits[j])?7'h09:0);crc7=c;end endfunction
 task respond;input[5:0]id;input[31:0]arg;input no_crc;reg[39:0]body;begin
  body={2'b00,id,arg};response={body,no_crc?7'h7f:crc7(body),1'b1};
  if(bad_response && (id==17 || id==18))response[1]=~response[1];
  response_len=48;pending=1;response_delay=8;response_pos=0;
 end endtask
 task command;input[47:0]bits;integer id;reg[31:0]arg;reg was_app;begin
  id=bits[45:40];arg=bits[39:8];was_app=app;app=0;commands=commands+1;
  if(bits[47:46]!=1 || bits[7:1]!==crc7(bits[47:8]) || bits[0]!=1)$fatal(1,"bad native command CRC %h",bits);
  case(id)
   0:begin
    if(bits[7:0]!=8'h95)$fatal(1,"known CMD0 CRC");
    stage=0;multi=0;wide=0;selected=0;pending=0;sending=0;drive=0;busy=0;after_read=0;after_busy=0;acmd41=0;
   end
   8:begin if(arg!=32'h1aa || bits[7:0]!=8'h87)$fatal(1,"known CMD8 pattern/CRC");respond(8,32'h1aa,0);end
   55:begin if(arg!=(selected?32'h12340000:0))$fatal(1,"CMD55 RCA");app=1;respond(55,32'h20,0);end
   41:begin if(!was_app || arg!=32'h40ff8000)$fatal(1,"ACMD41");acmd41=acmd41+1;respond(63,acmd41>=3?32'hc0ff8000:32'h40ff8000,1);end
   2:begin response={8'h3f,128'h123456789abcdef00123456789abcde1};response_len=136;pending=1;response_delay=8;response_pos=0;end
   3:respond(3,32'h12340700,0);
   7:begin if(arg!=32'h12340000)$fatal(1,"CMD7 RCA");selected=1;respond(7,32'h900,0);after_busy=12;end
   16:begin if(arg!=512 || !selected)$fatal(1,"CMD16");respond(16,32'h900,0);end
   6:begin if(!was_app || arg!=2 || !selected)$fatal(1,"ACMD6");wide=1;respond(6,32'h900,0);end
   17,18:begin
    if(!wide || !selected || multi)$fatal(1,"read before 4-bit selection/stop");
    lba=arg;card_index=locate(arg);multi=id==18;after_read=1;respond(id,32'h900,0);
    if(id==17)cmd17s=cmd17s+1;else cmd18s=cmd18s+1;
   end
   12:begin if(!multi)$fatal(1,"unexpected native stop");multi=0;stage=0;after_read=0;cmd12s=cmd12s+1;respond(12,32'h900,0);after_busy=16;end
   default:$fatal(1,"unexpected native CMD%0d",id);
  endcase
 end endtask
 always @(posedge sck)if(!power_rst)begin
  if(cmd!==0 && cmd!==1)$fatal(1,"CMD contention/unknown");
  if(!drive && (captured!=0 || cmd==0))begin
   capture={capture[46:0],cmd};captured=captured+1;
   if(captured==48)begin command(capture);captured=0;end
  end
 end
 reg[7:0]b;reg[3:0]nib;integer lane;
 always @(negedge sck)if(!power_rst)begin
  if(pending)begin
   if(response_delay!=0)response_delay=response_delay-1;
   else begin pending=0;sending=1;drive<=1;value<=#16 response[response_len-1];response_pos=1;end
  end else if(sending)begin
   if(response_pos<response_len)begin value<=#16 response[response_len-1-response_pos];response_pos=response_pos+1;end
   else begin
    drive<=0;sending=0;
    if(after_busy!=0)begin busy=after_busy;after_busy=0;end
    if(after_read)begin stage=1;delay_count=700;after_read=0;end
   end
  end
  nib=15;
  if(busy!=0)begin nib=14;busy=busy-1;end
  else case(stage)
   1:if(delay_count!=0)delay_count=delay_count-1;else begin nib=0;offset=0;stage=2;end
   2:begin b=datum(lba,offset/2);nib=offset%2?b[3:0]:b[7:4];offset=offset+1;if(offset==1024)begin stage=3;crc_index=0;end end
   3:begin
    for(lane=0;lane<4;lane=lane+1)nib[lane]=crc_ref[(DISK?(card_index<0?2047:card_index):(lba%256))*4+lane][15-crc_index];
    if(bad_crc && crc_index==0)nib[0]=~nib[0];
    crc_index=crc_index+1;if(crc_index==16)stage=4;
   end
   4:begin nib=15;if(multi)begin lba=lba+1;card_index=locate(lba);delay_count=3;stage=1;end else stage=0;end
  endcase
  dat<=#16 nib;
 end
 always @(posedge power_rst)begin drive=0;value=1;dat=15;captured=0;pending=0;sending=0;stage=0;multi=0;wide=0;selected=0;app=0;acmd41=0;busy=0;after_busy=0;after_read=0;end
 initial begin dat=15;
 if(DISK)begin
 $readmemh({FOLDER,"/info.hex"},info);count=info[0];
 $readmemh({FOLDER,"/lbas.hex"},lbas,0,count-1);
 $readmemh({FOLDER,"/data.hex"},disk,0,count*512-1);
 $readmemh({FOLDER,"/native_crc.hex"},crc_ref,0,count*4-1);
 // Unmapped post-file read-ahead contains FF, whose four lane CRCs are identical.
 crc_ref[8188]=16'heda9;crc_ref[8189]=16'heda9;crc_ref[8190]=16'heda9;crc_ref[8191]=16'heda9;
 end else $readmemh("sim/native_crc.hex",crc_ref,0,1023);
 end
endmodule
