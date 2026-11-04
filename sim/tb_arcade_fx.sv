`timescale 1ns/1ps
module tb_arcade_fx;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg view=1,selected=0;reg [2:0] state=1;reg [1:0] level=2,lives=3;
 reg [15:0] score=0;reg [31:0] bricks=32'hffffffff;
 reg [9:0] px=276,bx=320,tx0=160,tx1=140,tx2=120,x=1023,y=1023;
 reg [8:0] by=300,ty0=296,ty1=292,ty2=288;
 reg [3:0] hit=12;reg duck=0,h0=0,h1=0;wire [23:0] rgb;
 arcade_renderer #(.RUNNER_DUCK(1),.POLISH(1)) d(clk,rst,x,y,view,selected,state,level,lives,score,bricks,
  px,bx,tx0,tx1,tx2,by,ty0,ty1,ty2,10'd348,9'd166,hit,rgb,duck,h0,h1);
 task point(input integer xx,yy,input [23:0] expected);begin
  @(negedge clk);x=xx;y=yy;repeat(6)@(negedge clk);
  if(rgb!==expected)$fatal(1,"FX pixel %d,%d: %h expected %h",xx,yy,rgb,expected);
 end endtask
 task frame;begin
  @(negedge clk);x=0;y=479;repeat(3)@(negedge clk);
  x=1023;y=1023;repeat(3)@(negedge clk);
 end endtask
 task stream_line(input integer yy,marker,input [23:0] expected);integer n;begin
  for(n=0;n<643;n=n+1)begin
   @(negedge clk);x=n<640?n:0;y=yy;@(posedge clk);#1;
   if(n>=3 && ^rgb===1'bx)$fatal(1,"unknown stream pixel");
   if(n-3==marker && rgb!==expected)$fatal(1,"FX stream alignment %d,%d got%h",marker,yy,rgb);
  end
 end endtask
 integer i,c;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  point(325,300,24'h18453f);
  point(354,170,24'heaf1f7);
  point(342,162,24'heaf1f7);
  hit=6;point(366,176,24'hb9a3e8);point(330,156,24'hb9a3e8);
  point(366,156,24'hb9a3e8);point(330,176,24'hb9a3e8);
  stream_line(176,366,24'hb9a3e8);
  state=2;point(366,176,24'h080f1b);state=1;
  frame();score=16'h0010;frame();score=16'h0020;frame();
  if(d.combo!=2)$fatal(1,"two scored impacts should produce combo2");
  point(254,96,24'hb9a3e8);
  state=2;repeat(120)frame();
  if(d.combo!=2 || d.combo_hold!=90)$fatal(1,"pause changed combo timer");
  state=1;
  for(i=3;i<=9;i=i+1)begin score=i<<4;frame();end
  if(d.combo!=7)$fatal(1,"combo must saturate at7");
  c=d.combo_hold;@(negedge clk);x=0;y=479;repeat(12)@(negedge clk);
  if(d.combo_hold!=c-1)$fatal(1,"stationary coordinate generated multiple frame events");
  x=1023;y=1023;repeat(3)@(negedge clk);repeat(92)frame();
  if(d.combo!=0)$fatal(1,"combo did not expire");
  score=16'h0100;frame();state=0;frame();
  if(d.combo!=0)$fatal(1,"new life did not reset combo");
  state=1;selected=1;px=500;bx=620;by=352;ty0=0;
  point(176,236,24'h42576b);level=3;point(176,236,24'h506078);
  level=1;point(176,236,24'h15192f);
  duck=1;point(102,374,24'hef9d8c);
  stream_line(374,102,24'hef9d8c);
  point(106,378,24'heaf1f7);
  state=2;point(102,374,24'h0c1725);
  $display("PASS actual RGB glow and four-quadrant impact shards, state gating, combo accumulation/saturation/expiry/pause/reset, one-frame pulse, level speed lines and skid sparks; no RAM assets added");$finish;
 end
 initial begin #10000000;$fatal(1,"FX timeout");end
endmodule
