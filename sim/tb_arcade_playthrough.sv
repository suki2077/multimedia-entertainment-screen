`timescale 1ns/1ps
module tb_arcade_playthrough;
reg clk=0,rst=1,vs=1,active=1,lh=0,rh=0,ok=0;always #5 clk=~clk;
wire view;wire[2:0] state;wire[1:0] level,lives;wire[15:0] score;wire[31:0] bricks;wire[9:0] pad,bx;wire[8:0] by;
breakout_core d(.clk(clk),.rst(rst),.vs(vs),.active(active),.left_held(lh),.right_held(rh),.left_click(1'b0),.right_click(1'b0),.confirm(ok),
.view_game(view),.state(state),.level(level),.lives(lives),.score(score),.bricks(bricks),.paddle_x(pad),.ball_x(bx),.ball_y(by));
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame;begin vs=0;ticks(2);vs=1;ticks(40);end endtask
integer frames=0,target;
initial begin
ticks(4);rst=0;ticks(4);ok=1;ticks(1);ok=0;frame();
while(frames<200000 && state!=5)begin
 if(state==0 || state==3)begin ok=1;ticks(1);ok=0;frame();end
 else begin
  target=bx-44+(((frames/180)%3)-1)*24;
  if(target<36)target=36;if(target>516)target=516;
  lh=pad>target+3;rh=pad+3<target;frame();
 end
 frames=frames+1;
 if(state==4)$fatal(1,"autoplayer lost all lives at frame %d score %h level %d",frames,score,level);
 if(bx<34 || bx>606 || by<122 || by>448 || pad<36 || pad>516)$fatal(1,"position bounds");
 if(score[3:0]>9 || score[7:4]>9 || score[11:8]>9 || score[15:12]>9)$fatal(1,"invalid BCD");
end
if(state!=5 || score!=16'h0960 || level!=3 || bricks!=0)$fatal(1,"playthrough incomplete frames=%d score=%h level=%d bricks=%h",frames,score,level,bricks);
$display("PASS full three-level playthrough without internal state injection: %d frames, 96 bricks, score 0960, lives %d, valid positions and victory",frames,lives);$finish;
end
endmodule
