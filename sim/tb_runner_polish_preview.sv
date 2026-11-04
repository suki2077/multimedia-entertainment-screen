`timescale 1ns/1ps
module tb_runner_polish_preview;
reg clk=0,rst=1;always #5 clk=~clk;
reg view=0,selected=0;reg [2:0] state=0;reg[1:0] level=1,lives=3;reg[15:0] score=0;
reg[31:0] bricks=32'hffffffff;reg[9:0] px=276,bx=320,tx0=316,tx1=312,tx2=308;
reg [3:0] hit=0;
reg[8:0] by=406,ty0=338,ty1=342,ty2=346;reg[9:0] x=1023,y=1023;wire[23:0] rgb;
arcade_renderer d(clk,rst,x,y,view,selected,state,level,lives,score,bricks,px,bx,tx0,tx1,tx2,by,ty0,ty1,ty2,10'd348,9'd166,hit,rgb,1'b0,1'b0,1'b0);
integer f,n,xx,yy;
task render(input[255:0] name);begin
f=$fopen(name,"w");if(!f)$fatal(1,"render open");$fwrite(f,"P3\n640 480\n255\n");
for(n=0;n<307203;n=n+1)begin
xx=n<307200?n%640:0;yy=n<307200?n/640:0;
@(negedge clk);x=xx;y=yy;@(posedge clk);#1;
if(n>=3)begin if(^rgb===1'bx)$fatal(1,"unknown game pixel %d",n);$fwrite(f,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);end
end $fclose(f);$display("rendered %s",name);
end endtask
initial begin
#21;rst=0;
selected=1;render("preview/polish_menu.ppm");
view=1;tx0=160;tx1=3;tx2=64;px=330;bx=842;by=352;
render("preview/polish_ready.ppm");
state=1;by=352;ty0=12;render("preview/polish_ground.ppm");ty0=0;
state=1;score=16'h0120;level=2;by=260;px=210;bx=722;hit=12;
render("preview/polish_play.ppm");state=2;render("preview/polish_pause.ppm");
state=4;by=352;render("preview/polish_over.ppm");
$display("PASS six polished runner RTL frames: menu, READY, grounded/landing, jump, PAUSE and OVER; all pixels known");$finish;
end
initial begin #50000000;$fatal(1,"render timeout");end
endmodule
