`timescale 1ns/1ps
module tb_runner_slide;
 reg clk=0,rst=1,vs=1,active=1,jump=0,slide=0,confirm=0;always #5 clk=~clk;
 wire [2:0] state;wire [1:0] level;wire [15:0] score,best;wire [8:0] yy;
 wire [9:0] o0,o1,scroll;wire [3:0] glow;wire [4:0] fb;wire duck,h0,h1;
 runner_core #(.DUCK(1)) d(.clk(clk),.rst(rst),.vs(vs),.active(active),.jump(jump),.slide(slide),.confirm(confirm),.energy(4'd0),
 .state(state),.level(level),.score(score),.best(best),.runner_y(yy),.obstacle0(o0),.obstacle1(o1),.scroll(scroll),.glow(glow),.feedback(fb),.sliding(duck),.overhead0(h0),.overhead1(h1));
 task frame;begin @(negedge clk);vs=0;repeat(3)@(negedge clk);vs=1;repeat(3)@(negedge clk);end endtask
 task ok;begin @(negedge clk);confirm=1;@(negedge clk);confirm=0;frame();end endtask
 task retry;begin slide=0;jump=0;ok();if(state!=1)$fatal(1,"retry");end endtask
 integer last_type=-1,streak=0,observed=0;
 integer n,spd,target,types=0,gaps=0,wraps=0;reg wjump,wslide;reg [9:0] saved_o;reg [8:0] saved_y;
 initial begin
  repeat(4)@(negedge clk);rst=0;ok();
  @(negedge clk);d.obstacle0=170;d.overhead0=1;d.obstacle1=600;frame();
  if(state!=4)$fatal(1,"standing passed hanging gate");retry();
  @(negedge clk);d.obstacle0=170;d.overhead0=1;d.obstacle1=600;slide=1;frame();
  if(state!=1 || !duck || yy!=352)$fatal(1,"first-frame sliding lane");
  jump=1;frame();jump=0;if(d.velocity!=0 || yy!=352)$fatal(1,"simultaneous slide/jump");
  ok();saved_o=o0;saved_y=yy;slide=0;repeat(12)frame();
  if(state!=2 || o0!=saved_o || yy!=saved_y || !duck)$fatal(1,"slide pause drift");
  slide=1;ok();frame();if(state!=1 || !duck)$fatal(1,"resume slide");
  @(negedge clk);d.obstacle0=170;d.overhead0=0;frame();
  if(state!=4)$fatal(1,"sliding passed ground obstacle");retry();
  @(negedge clk);d.obstacle0=170;d.overhead0=1;d.obstacle1=600;d.runner_y=250;d.velocity=0;slide=1;frame();
  if(state!=4)$fatal(1,"airborne slide bypassed gate");retry();
  for(n=0;n<24000;n=n+1)begin
   spd=level==1?4:level==2?5:6;target=level==1?228:level==2?244:256;
   wslide=(h0 && o0<=230 && o0>=100)||(h1 && o1<=230 && o1>=100);
   wjump=yy==352 && ((!h0 && o0<=target && o0>target-spd)||(!h1 && o1<=target && o1>target-spd));
   if(d.recycle0 || d.recycle1)begin gaps=gaps|(d.gap==320?1:d.gap==384?2:4);wraps=wraps+1;end
   if(d.passed_column)begin
    if(o0>=128 && o0<960 && d.nx0<128)begin
     if(last_type==h0)$fatal(1,"repeated action at slot0");last_type=h0;observed=observed+1;
    end
    if(o1>=128 && o1<960 && d.nx1<128)begin
     if(last_type==h1)$fatal(1,"repeated action at slot1");last_type=h1;observed=observed+1;
    end
    if(o0>=128 && o0<960 && d.nx0<128)types=types|(h0?2:1);
    if(o1>=128 && o1<960 && d.nx1<128)types=types|(h1?8:4);
   end
   @(negedge clk);jump=wjump;slide=wslide;frame();jump=0;
   if(state!=1)$fatal(1,"unfair mixed course n=%0d level=%0d y=%0d obs=%0d/%0d head=%b/%b slide=%b",n,level,yy,o0,o1,h0,h1,slide);
  end
  if(types!=9 || gaps!=7 || wraps<127 || observed<127 || level!=3)$fatal(1,"mixed coverage %d %d %d",types,gaps,wraps);
  $display("PASS slide/standing/airborne collision matrix, pause/resume, exclusive actions, 24000-frame fair mixed course, strict alternating jump/slide across >127 obstacles, both slots, 3 gaps, 3 speeds and LFSR cycle");$finish;
 end
 initial begin #6000000;$fatal(1,"timeout");end
endmodule
