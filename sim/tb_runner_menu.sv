`timescale 1ns/1ps
module tb_runner_menu;
reg clk=0,rst=1,vs=1,active=1,lc=0,rc=0,ok=0;always #5 clk=~clk;
wire view,sel;wire [2:0] bs,rs;wire[15:0] score,best;
breakout_core #(.RUNNER(1)) b(.clk(clk),.rst(rst),.vs(vs),.active(active),.left_held(1'b0),.right_held(1'b0),.left_click(lc),.right_click(rc),.confirm(ok),.view_game(view),.selected(sel),.state(bs));
runner_core r(.clk(clk),.rst(rst),.vs(vs),.active(active && view && sel),.jump(lc||rc),.confirm(ok),.energy(4'd12),.state(rs),.score(score),.best(best));
task tick;begin repeat(6)@(negedge clk);end endtask
task frame;begin vs=0;tick();vs=1;tick();end endtask
task press(input integer key);begin @(negedge clk);if(key==0)rc=1;else ok=1;@(negedge clk);rc=0;ok=0;frame();end endtask
initial begin
tick();rst=0;frame();if(view||sel)$fatal(1,"initial menu");
press(0);if(!sel||view)$fatal(1,"runner select");press(1);if(!view||rs!=0)$fatal(1,"entry event leaked");
press(1);if(rs!=1)$fatal(1,"runner start");press(0);if(r.velocity!=-15)$fatal(1,"runner jump");
if(bs!=0)$fatal(1,"breakout advanced while runner active");
press(1);if(rs!=2)$fatal(1,"runner pause");repeat(10)frame();if(rs!=2)$fatal(1,"paused");
press(1);if(rs!=1)$fatal(1,"resume");
@(negedge clk);r.score=16'h0120;tick();if(best!=16'h0120)$fatal(1,"best");
active=0;frame();if(view||rs!=0)$fatal(1,"HOME");active=1;frame();press(1);if(!view||rs!=0||best!=16'h0120)$fatal(1,"reentry");
active=0;frame();active=1;frame();press(0);if(sel)$fatal(1,"breakout select");press(1);press(1);if(bs!=1||rs!=0)$fatal(1,"breakout start isolation");
$display("PASS two-game menu entry isolation, independent game states, jump/pause/resume, HOME/reentry and retained best");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
