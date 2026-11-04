`timescale 1ns/1ps
module tb_renderer_equivalence;
reg clk=0,rst=1;always #5 clk=~clk;
reg view=1,selected=0;reg[2:0] state=1;reg[1:0] level=2,lives=3;reg[15:0] score=16'h0120;reg[31:0] bricks=32'hffffffff;
reg[9:0] px=210,bx=722,tx0=160,tx1=3,tx2=64;reg[3:0] hit=12;reg[8:0] by=260,ty0=0,ty1=0,ty2=0;reg[9:0] x=0,y=0;wire[23:0] rgb,reference;
arcade_renderer d(clk,rst,x,y,view,selected,state,level,lives,score,bricks,px,bx,tx0,tx1,tx2,by,ty0,ty1,ty2,10'd348,9'd166,hit,rgb,1'b0,1'b0,1'b0);
arcade_renderer_reference c(clk,rst,x,y,view,selected,state,level,lives,score,bricks,px,bx,tx0,tx1,tx2,by,ty0,ty1,ty2,10'd348,9'd166,hit,reference);
integer n,k;
initial begin repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);
for(k=0;k<2;k=k+1)begin by=k==0?334:406;state=k==0?1:2;
for(n=0;n<307205;n=n+1)begin @(negedge clk);x=n<307200?n%640:0;y=n<307200?n/640:0;@(posedge clk);#1;if(rgb!==reference)$fatal(1,"RGB difference at input %0d,%0d frame=%0d got=%h ref=%h",x,y,k,rgb,reference);end end
$display("PASS 614400 breakout visible pixels remain bit-identical to prior release in PLAY and PAUSE, including font and pipeline");$finish;end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
