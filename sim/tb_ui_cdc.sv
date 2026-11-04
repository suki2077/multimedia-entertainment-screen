`timescale 1ns/1ps
module tb_ui_cdc;
reg clk=0,rst=1,vs=1,toggle=0;reg[6:0] state=0;always #5 clk=~clk;
wire[2:0] page;wire[1:0] home,focus;
ui_state_cdc d(clk,rst,vs,toggle,state,page,home,focus);
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame;begin vs=0;ticks(1);vs=1;ticks(2);end endtask
task send(input[6:0] v);begin #2;state=v;toggle=~toggle;ticks(8);end endtask
initial begin
ticks(3);rst=0;ticks(5);
send(6'b111001);if({page,home,focus}!=0)$fatal(1,"changed outside blank");
send(6'b010110);frame();if({page,home,focus}!=6'b010110)$fatal(1,"latest pending state lost");
frame();if({page,home,focus}!=6'b010110)$fatal(1,"unrequested update");
state=6'b100011;toggle=~toggle;ticks(3);vs=0;ticks(1);vs=1;ticks(3);
if({page,home,focus}!=6'b100011)$fatal(1,"event/VS simultaneous commit");
send(0);frame();if({page,home,focus}!=0)$fatal(1,"HOME state");
send(7'b1001101);frame();if({page,home,focus}!=7'b1001101)$fatal(1,"VIDEO state lost");
$display("PASS VIDEO id and bundled UI CDC stable between frames, latest event wins, full-state atomic VS commit including simultaneous event");$finish;
end
initial begin #100000;$fatal(1,"CDC timeout");end
endmodule
