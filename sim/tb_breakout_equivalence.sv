`timescale 1ns/1ps
module tb_breakout_equivalence;
reg clk=0,rst=1,vs=1,active=1,lh=0,rh=0,lc=0,rc=0,ok=0;always #5 clk=~clk;
wire[253:0] got,expected;
wire a_vw,a_sel;wire[2:0] a_st;wire[1:0] a_lv,a_li;wire[15:0] a_sc;wire[31:0] a_br;
wire[9:0] a_px,a_bx,a_t0,a_t1,a_t2,a_hx;wire[8:0] a_by,a_y0,a_y1,a_y2,a_hy;wire[3:0] a_ht;
breakout_core a(.clk(clk),.rst(rst),.vs(vs),.active(active),.left_held(lh),.right_held(rh),.left_click(lc),.right_click(rc),.confirm(ok),.view_game(a_vw),.selected(a_sel),.state(a_st),.level(a_lv),.lives(a_li),.score(a_sc),.bricks(a_br),.paddle_x(a_px),.ball_x(a_bx),.ball_y(a_by),.trail_x0(a_t0),.trail_x1(a_t1),.trail_x2(a_t2),.trail_y0(a_y0),.trail_y1(a_y1),.trail_y2(a_y2),.hit_x(a_hx),.hit_y(a_hy),.hit_timer(a_ht));
assign got={a_vw,a_sel,a_st,a_lv,a_li,a_sc,a_br,a_px,a_bx,a_by,a_t0,a_t1,a_t2,a_y0,a_y1,a_y2,a_hx,a_hy,a_ht};
wire b_vw,b_sel;wire[2:0] b_st;wire[1:0] b_lv,b_li;wire[15:0] b_sc;wire[31:0] b_br;
wire[9:0] b_px,b_bx,b_t0,b_t1,b_t2,b_hx;wire[8:0] b_by,b_y0,b_y1,b_y2,b_hy;wire[3:0] b_ht;
breakout_reference b(.clk(clk),.rst(rst),.vs(vs),.active(active),.left_held(lh),.right_held(rh),.left_click(lc),.right_click(rc),.confirm(ok),.view_game(b_vw),.selected(b_sel),.state(b_st),.level(b_lv),.lives(b_li),.score(b_sc),.bricks(b_br),.paddle_x(b_px),.ball_x(b_bx),.ball_y(b_by),.trail_x0(b_t0),.trail_x1(b_t1),.trail_x2(b_t2),.trail_y0(b_y0),.trail_y1(b_y1),.trail_y2(b_y2),.hit_x(b_hx),.hit_y(b_hy),.hit_timer(b_ht));
assign expected={b_vw,b_sel,b_st,b_lv,b_li,b_sc,b_br,b_px,b_bx,b_by,b_t0,b_t1,b_t2,b_y0,b_y1,b_y2,b_hx,b_hy,b_ht};
integer n;reg[31:0] seed=32'hc17e0213;
task frame;begin vs=0;repeat(2)@(negedge clk);vs=1;repeat(44)@(negedge clk);if(got!==expected)$fatal(1,"frame equivalence %0d got=%h ref=%h",n,got,expected);end endtask
initial begin repeat(4)@(negedge clk);rst=0;ok=1;frame();ok=0;frame();ok=1;frame();ok=0;
for(n=0;n<2000;n=n+1)begin
seed={seed[30:0],seed[31]^seed[21]^seed[1]^seed[0]};
lh=seed[0];rh=seed[3];ok=seed[7:3]==5'd1;
// Restart deliberately at HOME periodically; never change inputs mid-blank.
active=n%257!=256;frame();
end
$display("PASS pipelined breakout equals previous release on all public game outputs at 2000 frame boundaries with deterministic navigation, movement, pause/retry and HOME");$finish;end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
