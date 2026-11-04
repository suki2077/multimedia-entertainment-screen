`timescale 1ns/1ps
module tb_breakout_polish;
reg clk=0,rst=1,vs=1,ok=0,lh=0,rh=0;always #5 clk=~clk;
wire [2:0] state;wire [3:0] timer;wire [9:0] hx;wire [8:0] hy;wire [31:0] bricks;
breakout_core d(.clk(clk),.rst(rst),.vs(vs),.active(1'b1),.left_held(lh),.right_held(rh),
 .left_click(1'b0),.right_click(1'b0),.confirm(ok),.state(state),.hit_timer(timer),.hit_x(hx),.hit_y(hy),.bricks(bricks));
task frame;begin @(negedge clk);vs=0;repeat(2)@(negedge clk);vs=1;repeat(40)@(negedge clk);end endtask
task confirm;begin @(negedge clk);ok=1;@(negedge clk);ok=0;frame();end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;confirm();lh=1;confirm();
 if(state!=1 || d.vel_x!=-8)$fatal(1,"left serve aim");lh=0;
 // A descending ball crosses the paddle; feedback reuses the old timer.
 @(negedge clk);d.ball_fx=13'd1280;d.ball_fy=13'd1636;d.vel_y=10;frame();
 if(d.vel_y>=0 || timer!=8 || hy!=412 || hx<319 || hx>326)$fatal(1,"paddle impact feedback/rebound");
 confirm();repeat(4)frame();if(timer!=7)$fatal(1,"paused effect drift");confirm();
 // The visible gap [120,128) between adjacent 56px bricks is empty.
 @(negedge clk);d.ball_fx=13'd496;d.ball_fy=13'd544;d.vel_x=0;d.vel_y=0;frame();
 if(bricks!=32'hffffffff)$fatal(1,"invisible brick edge collided");
 // A real face still destroys exactly one brick and scores once.
 @(negedge clk);d.ball_fx=13'd400;d.ball_fy=13'd544;frame();
 if(bricks!=32'hfffffffe || d.score!=16'h0010 || timer!=12)$fatal(1,"visible brick hit");
 $display("PASS directional serve, paddle impact, pause freeze, visible-gap miss, exact visible brick hit");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
