`timescale 1ns/1ps
module sd_latency_fixture(input wire clk,rst,cs,sck,mosi,output reg miso);
 initial miso=1;integer bitno=0,cmdpos=0,resp_pos=0,resp_len=0;
 reg[7:0]rx=0,tx=255,cb[0:5],response[0:15];
 integer card_stage=0,token_left=0,data_index=0,card_lba=0;
 integer cmd17s=0,cmd18s=0,cmd12s=0;
 integer first_token=700,next_token=3;reg multi=0,idle_card=1;
reg[31:0] info[0:2],lbas[0:2047];reg[7:0]disk[0:1048575];integer count=0,card_index=-1;
 function integer locate;input integer address;integer k;begin locate=-1;for(k=0;k<count;k=k+1)if(lbas[k]==address)locate=k;end endfunction
 function[7:0] datum;input integer blockno,offset;begin datum=card_index<0?255:disk[card_index*512+offset];end endfunction
 task process_command;
  integer id,arg;
  begin
   id=cb[0]&63;arg={cb[1],cb[2],cb[3],cb[4]};
   resp_pos=0;resp_len=1;response[0]=idle_card?1:0;
   case(id)
    0:begin idle_card=1;response[0]=1;multi=0;card_stage=0;end
    8:begin resp_len=5;response[0]=1;response[1]=0;response[2]=0;response[3]=1;response[4]=170;end
    55:begin end
    41:begin idle_card=0;response[0]=0;end
    16:begin if(arg!=512)$fatal(1,"CMD16 size");end
    17,18:begin
     if(multi)$fatal(1,"new read before CMD12");
     multi=id==18;card_lba=arg;card_index=locate(arg);card_stage=1;token_left=first_token;data_index=0;
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
    2:begin tx=datum(card_lba,data_index);data_index=data_index+1;if(data_index==512)card_stage=3;end
    3:begin tx=255;card_stage=4;end
    4:begin tx=255;if(multi)begin card_stage=1;token_left=next_token;card_lba=card_lba+1;card_index=locate(card_lba);end else card_stage=0;end
    default:tx=255;
   endcase
  end
 endtask
 always @(posedge cs)begin
  if(multi && !rst)$fatal(1,"CS released before CMD12");
  bitno=0;cmdpos=0;resp_len=0;resp_pos=0;tx=255;miso=1;
 end
 // Model a finite card output delay rather than ideal zero-delay MISO.
 always @(negedge sck)if(!cs)miso <= #8 tx[7-bitno];
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
 initial begin
 $readmemh("sim/fixtures/responsive/info.hex",info);count=info[0];
 $readmemh("sim/fixtures/responsive/lbas.hex",lbas,0,count-1);
 $readmemh("sim/fixtures/responsive/data.hex",disk,0,count*512-1);
 end
endmodule
