`timescale 1ns/1ps
module tb_hq_store;
 reg clk=0,rst=1,paused=0,source=0,req=0;always #7.5 clk=~clk;
 reg [8:0] row=0;wire accept,we,re,lwe,ack,ready,pending;wire[20:0]wa,ra;wire[31:0]wd,ld,frames,late_count;wire[10:0]la;wire[8:0]te,to;wire ve,vo;
 integer offered=0,written=0,i,n=0,j,bank,index,expect_row,checked=0;integer bank_frame[0:3];
 reg [2:0] rv=0;reg[31:0]d0=0,d1=0,d2=0;
 function [31:0] datum(input integer f,off);datum=(f<<24)|off;endfunction
 wire[31:0] input_word=datum(offered/64800,offered%64800);
 video_store s(clk,rst,1'b1,1'b0,paused,source,1'b1,input_word,accept,we,wa,wd,re,ra,rv[2],d2,req,row,ack,lwe,la,ld,te,to,ve,vo,ready,frames,late_count,pending);
 always @(posedge clk)if(!rst)begin
  if(accept)offered<=offered+1;
  rv<={rv[1:0],re};d1<=d0;d2<=d1;
  if(re)begin
   bank=(ra-1228800)/64800;index=(ra-1228800)%64800;
   if(bank<0 || bank>3 || index>=64800)$fatal(1,"read outside video slots");
   d0<=datum(bank_frame[bank],index);
  end
  if(we)begin
   bank=(written/64800+1)%4;index=written%64800;
   if(wa!==1228800+bank*64800+index || wd!==datum(written/64800,index))$fatal(1,"write layout/data %d %d %h",written,wa,wd);
   if(ready && bank==s.display_bank)$fatal(1,"active frame overwritten");
   bank_frame[bank]=written/64800;written=written+1;
  end
  if(lwe && ready)begin
   if(la!==row[0]*1024+n || ld!==datum(bank_frame[s.display_bank],expect_row*240+n))$fatal(1,"line row=%d native=%d word=%d addr=%d data=%h",row,expect_row,n,la,ld);
   n=n+1;checked=checked+1;
  end
 end
 task fetch(input integer r);begin
  @(negedge clk);row=r;expect_row=r*9/16;n=0;req=~req;
  wait(ack==req);@(negedge clk);
  if(n!=240 || (r%2==0?te:to)!=r)$fatal(1,"line length/tag %d %d",r,n);
 end endtask
 initial begin
  for(i=0;i<4;i=i+1)bank_frame[i]=-1;
  repeat(4)@(negedge clk);rst=0;wait(ready);repeat(6)@(negedge clk);
  for(j=0;j<8;j=j+1)begin
   fetch(1);fetch(238);fetch(479);
   wait(pending);@(negedge clk);source=~source;repeat(6)@(negedge clk);
   if(j==3)begin paused=1;fetch(0);if(frames!=j+1)$fatal(1,"pause advanced");paused=0;end
   fetch(0);if(frames!=j+2 || s.display_bank!=((j+2)%4))$fatal(1,"frame ring %d %d",frames,s.display_bank);
  end
  $display("PASS HQ SDRAM 4-slot ring across 8 advances, exact writes/stride/all 240 line words, top/middle/bottom mapping, both line banks, pause retention, no active overwrite; checked=%d writes=%d",checked,written);$finish;
 end
 initial begin #200000000;$fatal(1,"store timeout");end
endmodule
