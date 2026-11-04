`timescale 1ns/1ps
module tb_runner;
 reg clk=0,rst=1,vs=1,active=0,jump=0,confirm=0;reg [3:0] energy=0;always #5 clk=~clk;
 wire [2:0] state;wire [1:0] level;wire [15:0] score,best;wire [8:0] yy;wire [9:0] o0,o1,scroll;wire [3:0] glow;
 wire [4:0] feedback;
 runner_core d(.clk(clk),.rst(rst),.vs(vs),.active(active),.jump(jump),.confirm(confirm),.energy(energy),.state(state),.level(level),.score(score),.best(best),.runner_y(yy),.obstacle0(o0),.obstacle1(o1),.scroll(scroll),.glow(glow),.feedback(feedback),.slide(1'b0));
 task tick;begin repeat(4)@(negedge clk);end endtask
 task frame;begin vs=0;tick();vs=1;tick();end endtask
 task press(input integer k);begin @(negedge clk);if(k==0)jump=1;else confirm=1;@(negedge clk);jump=0;confirm=0;frame();end endtask
 integer gaps=0,wraps=0;reg[4:0] oldfb;reg[6:0] oldcourse;
 integer n,refy,refv,old0,old1,olds,oldy,oldscore,speed,target;reg want_jump;
 initial begin
  tick();rst=0;press(1);if(state!=0)$fatal(1,"inactive confirm");active=1;frame();press(1);if(state!=1)$fatal(1,"start");
  press(0);if(d.velocity!=-15 || yy!=352)$fatal(1,"queued jump");refy=352;refv=-15;
  for(n=0;n<32;n=n+1)begin
   refy=refy+refv;if(refy>=352)begin refy=352;refv=0;end else refv=refv+1;
   frame();if(yy!=refy || d.velocity!=refv)$fatal(1,"jump trajectory %0d y=%0d/%0d vy=%0d/%0d",n,yy,refy,d.velocity,refv);
  end
  energy=15;frame();if(glow!=15)$fatal(1,"audio attack");energy=0;frame();if(glow!=14)$fatal(1,"audio decay");
  press(1);old0=o0;old1=o1;olds=scroll;oldy=yy;oldscore=score;oldfb=feedback;oldcourse=d.course;
  repeat(100)frame();if(state!=2 || o0!=old0 || o1!=old1 || scroll!=olds || yy!=oldy || score!=oldscore || feedback!=oldfb || d.course!=oldcourse)$fatal(1,"pause drift");press(1);
  @(negedge clk);d.runner_y=350;d.velocity=4;d.obstacle0=600;
  press(0);if(yy!=352 || feedback!=12)$fatal(1,"landing clamp/feedback");frame();if(d.velocity!=-15)$fatal(1,"landing jump buffer");
  @(negedge clk);d.runner_y=250;d.velocity=0;d.obstacle0=130;d.score=16'h0090;d.passed=7;
  frame();if(score!=16'h0100 || level!=2 || feedback!=28)$fatal(1,"BCD score/difficulty");
  @(negedge clk);d.runner_y=352;d.velocity=0;d.obstacle0=170;
  frame();if(state!=4)$fatal(1,"collision");frame();if(best!=16'h0100)$fatal(1,"best score");
  press(1);if(state!=1 || score!=0 || level!=1 || best!=16'h0100)$fatal(1,"retry");
  // Deterministic controller demonstrates a fair, survivable course at all
  // three speeds, including modulo wrap, both column heights and long runs.
  for(n=0;n<24000;n=n+1)begin
   speed=level==1?4:level==2?5:6;target=level==1?228:level==2?244:256;
   want_jump=yy==352 && ((o0<=target && o0>target-speed)||(o1<=target && o1>target-speed));
   if(d.recycle0 || d.recycle1)begin
    gaps=gaps|(d.gap==320?1:d.gap==384?2:d.gap==448?4:0);wraps=wraps+1;
   end
   @(negedge clk);jump=want_jump;@(negedge clk);jump=0;frame();
   if(state!=1)$fatal(1,"unfair course frame=%0d level=%0d y=%0d obstacles=%0d,%0d",n,level,yy,o0,o1);
   if(yy>352 || yy<220)$fatal(1,"position overflow");
  end
  if(gaps!=7 || wraps<127)$fatal(1,"missing varied-course coverage %d/%d",gaps,wraps);
  if(level!=3 || score<16'h0400)$fatal(1,"long-run coverage");
  @(negedge clk);d.obstacle0=600;d.obstacle1=170;d.runner_y=352;d.velocity=0;
  frame();if(state!=4)$fatal(1,"tall obstacle collision");
  oldscore=score;active=0;frame();if(state!=0 || score!=0 || best<oldscore)$fatal(1,"HOME/best persistence");
  active=1;frame();press(1);@(negedge clk);d.score=16'h9990;d.obstacle0=130;d.runner_y=250;d.velocity=0;
  frame();if(score!=16'h9990)$fatal(1,"score saturation");
  $display("PASS runner queued jump, exact gravity/landing, audio attack/decay, pause/resume, BCD/level/collision/retry/best, 24000-frame fair course, all 3 gaps and 3 speeds, full LFSR cycle, both collisions, feedback/pause and saturation");$finish;
 end
 initial begin #5000000;$fatal(1,"runner timeout");end
endmodule
