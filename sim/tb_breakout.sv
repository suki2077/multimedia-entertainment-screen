`timescale 1ns/1ps
module tb_breakout;
reg clk=0,rst=1,vs=1,active=0,lh=0,rh=0,lc=0,rc=0,ok=0;
always #5 clk=~clk;
wire view,selected;wire[2:0] state;wire[1:0] level,lives;wire[15:0] score;wire[31:0] bricks;
wire[9:0] pad,bx;wire[8:0] by;
breakout_core d(.clk(clk),.rst(rst),.vs(vs),.active(active),.left_held(lh),.right_held(rh),
.left_click(lc),.right_click(rc),.confirm(ok),.view_game(view),.selected(selected),.state(state),
.level(level),.lives(lives),.score(score),.bricks(bricks),.paddle_x(pad),.ball_x(bx),.ball_y(by));
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame;begin vs=0;ticks(2);vs=1;ticks(40);end endtask
task click;begin ok=1;ticks(1);ok=0;ticks(2);frame();end endtask
task hit(input integer idx,input integer direction);integer xx,yy;begin
xx=64+(idx%8)*64;yy=128+(idx/8)*28;
@(negedge clk);d.state=1;d.phase=0;d.remaining=32;d.bricks=32'hffffffff;d.score=0;d.level=1;
case(direction)
0:begin d.ball_fx=(xx+28)*4;d.ball_fy=(yy-6)*4;d.vel_x=0;d.vel_y=12;end
1:begin d.ball_fx=(xx+28)*4;d.ball_fy=(yy+26)*4;d.vel_x=0;d.vel_y=-12;end
2:begin d.ball_fx=(xx-6)*4;d.ball_fy=(yy+10)*4;d.vel_x=12;d.vel_y=0;end
3:begin d.ball_fx=(xx+62)*4;d.ball_fy=(yy+10)*4;d.vel_x=-12;d.vel_y=0;end
endcase
frame();
if(bricks!==(32'hffffffff^(32'h1<<idx)) || score!=16'h0010 || d.remaining!=31)$fatal(1,"brick %d direction %d: mask %h score %h",idx,direction,bricks,score);
if((direction==0 && (d.vel_y!=-12 || by!=yy-4)) || (direction==1 && (d.vel_y!=12 || by!=yy+24)) ||
 (direction==2 && (d.vel_x!=-12 || bx!=xx-4)) || (direction==3 && (d.vel_x!=12 || bx!=xx+60)))$fatal(1,"brick reflection/snap %d dir %d xy %d %d",idx,direction,bx,by);
end endtask
integer i,j,oldx,oldy;
initial begin
ticks(4);rst=0;ticks(4);ok=1;frame();ok=0;
if(view)$fatal(1,"inactive confirm leaked");
active=1;rc=1;ticks(1);rc=0;frame();if(!selected)$fatal(1,"second slot select");
click();if(view)$fatal(1,"reserved snake slot entered unfinished game");
lc=1;ticks(1);lc=0;frame();click();if(!view || state!=0 || lives!=3 || level!=1)$fatal(1,"new game");
lh=1;repeat(100)frame();lh=0;if(pad!=36 || bx!=80)$fatal(1,"left clamp/follow");
rh=1;repeat(100)frame();rh=0;if(pad!=516 || bx!=560)$fatal(1,"right clamp/follow");
click();if(state!=1)$fatal(1,"serve");frame();click();if(state!=2)$fatal(1,"pause");
oldx=d.ball_fx;oldy=d.ball_fy;repeat(20)frame();if(d.ball_fx!=oldx || d.ball_fy!=oldy)$fatal(1,"paused physics moved");
click();if(state!=1)$fatal(1,"resume");
// Every brick and both horizontal and vertical collision normals.
for(i=0;i<32;i=i+1)for(j=0;j<4;j=j+1)hit(i,j);
// BCD carry, shared wall corner and empty-cell traversal.
@(negedge clk);d.bricks=0;d.state=1;d.ball_fx=2420;d.ball_fy=492;d.vel_x=12;d.vel_y=-12;
frame();if(bx!=606 || by!=122 || d.vel_x!=-12 || d.vel_y!=12)$fatal(1,"wall corner");
for(i=0;i<3;i=i+1)begin
@(negedge clk);d.paddle_x=276;d.state=1;d.bricks=0;d.ball_fx=(286+i*34)*4;d.ball_fy=1632;d.vel_y=12;d.vel_x=8;
frame();if(by!=410 || d.vel_y!=-10 || (i==0 && d.vel_x!=-12) || (i==1 && d.vel_x!=4) || (i==2 && d.vel_x!=12))$fatal(1,"paddle angle %d vx=%d vy=%d xy=%d,%d",i,d.vel_x,d.vel_y,bx,by);
end
@(negedge clk);d.state=1;d.lives=3;d.ball_fy=1788;d.vel_y=12;d.ball_fx=400;d.vel_x=0;
frame();if(lives!=2 || state!=0)$fatal(1,"life loss");repeat(10)frame();if(lives!=2)$fatal(1,"lost multiple lives waiting to serve");
@(negedge clk);d.state=1;d.lives=1;d.ball_fy=1788;d.vel_y=12;
frame();if(lives!=0 || state!=4)$fatal(1,"game over");click();if(lives!=3 || state!=0 || score!=0)$fatal(1,"retry reset");
// The last brick clears level one, and level three ends in victory.
for(i=1;i<=3;i=i+2)begin
@(negedge clk);d.state=1;d.level=i;d.bricks=32'h80000000;d.remaining=1;d.score=16'h0090;
d.ball_fx=540*4;d.ball_fy=206*4;d.vel_x=0;d.vel_y=12;
frame();if(score!=16'h0100 || bricks!=0 || state!=(i==3?5:3))$fatal(1,"last brick/BCD/level %d state %d",i,state);
click();if(state!=0 || level!=(i==3?1:2) || bricks!=32'hffffffff)$fatal(1,"next level/replay");
end
active=0;frame();active=1;frame();if(view)$fatal(1,"HOME must return to game menu");
$display("PASS 128 brick collision vectors, all normals and snaps, wall corner, paddle steering, held-key clamps, queued menu commands, pause/resume, one-time life loss, retry, BCD carry, levels and victory, HOME isolation");$finish;
end
initial begin #10000000;$fatal(1,"breakout timeout");end
endmodule
