`timescale 1ns/1ps
module tb_auto_transition;
reg clk=0,rst=1,vs=1,pending=0,ready=1;always #5 clk=~clk;
wire[4:0] level;wire swap;wire[1:0] mode;
fade_control #(.AUTO_CYCLE(1)) d(clk,rst,vs,pending,ready,level,swap,2'd2,mode);
task ticks;begin repeat(6)@(negedge clk);end endtask
task frame;begin vs=0;ticks();vs=1;ticks();end endtask
integer k,n,expected;
initial begin ticks();rst=0;ticks();
for(k=0;k<7;k=k+1)begin
expected=k%3;pending=1;ticks();if(mode!=expected)$fatal(1,"auto sequence %0d",k);
for(n=15;n>=0;n=n-1)begin frame();if(level!=n||mode!=expected||swap!==(n==0))$fatal(1,"out mode/level");end
pending=0;ticks();if(mode!=expected)$fatal(1,"mode changed across swap");
for(n=1;n<=16;n=n+1)begin frame();if(level!=n||swap)$fatal(1,"in level");if(n<16 && mode!=expected)$fatal(1,"mid-in mode");end
end
// An abandoned request never reaches BLACK and must not consume an effect.
expected=1;pending=1;ticks();repeat(4)frame();pending=0;ticks();repeat(16)frame();if(mode!=expected)$fatal(1,"cancel consumed effect");
ready=0;ticks();if(level!=16||swap||mode!=0)$fatal(1,"memory recovery");
$display("PASS 7 successful image transactions cycle fade/wipe/blinds, identical out/in mode, black-only swap, no sequence advance on abandoned request and reset/recovery");$finish;end
initial begin #100000;$fatal(1,"timeout");end
endmodule
