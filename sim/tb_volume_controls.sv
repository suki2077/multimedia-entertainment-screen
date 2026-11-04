`timescale 1ns/1ps
module tb_volume_controls;
reg vm=0;reg clk=0,rst=1,vs=1,toggle=0;reg[1:0] cmd=0;reg[3:0] switches=7;
always #5 clk=~clk;
wire[1:0] bright;wire sound,period;wire[2:0] volume;
media_controls #(.DEBOUNCE_CYCLES(3)) d(clk,rst,switches,vs,vm,toggle,cmd,bright,sound,period,volume,,);
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame;begin vs=0;ticks(1);vs=1;ticks(2);end endtask
task adjust(input[1:0] c);begin cmd=c;toggle=~toggle;ticks(8);end endtask
task check(input[1:0] b,input s,p,input[2:0] v);begin
if({bright,sound,period,volume}!={b,s,p,v})$fatal(1,"settings %b expected %b",{bright,sound,period,volume},{b,s,p,v});
end endtask
integer n;
initial begin
ticks(3);rst=0;ticks(10);check(3,1,0,4);
adjust(1);check(3,1,0,4);frame();check(3,1,0,3);
for(n=2;n>=0;n=n-1)begin adjust(1);frame();check(3,1,0,n);end
adjust(1);frame();check(3,1,0,4);
repeat(5)adjust(1);frame();check(3,1,0,4);
repeat(27)adjust(1);frame();check(3,1,0,2);
adjust(0);adjust(2);frame();check(0,1,1,2);
switches=5;ticks(16);frame();check(1,1,1,2);
switches=1;ticks(16);frame();check(1,0,1,2);
adjust(1);frame();check(1,0,1,1);
switches=5;ticks(16);frame();check(1,1,1,1);
switches=13;ticks(16);frame();check(1,1,1,1);
adjust(2);frame();check(1,1,0,1);
cmd=1;toggle=~toggle;ticks(3);vs=0;ticks(1);vs=1;ticks(3);check(1,1,0,0);
frame();check(1,1,0,0);
rst=1;ticks(3);rst=0;switches=7;vm=1;ticks(20);
repeat(6)begin adjust(1);frame();end
if(volume!=0)$fatal(1,"VIDEO down must clamp");
repeat(6)begin adjust(3);frame();end
if(volume!=4)$fatal(1,"VIDEO up must clamp");
$display("PASS VIDEO saturation and frame-latched volume 100/75/50/25/0, five-step wrap, 27 queued commands, brightness/interval independence, mute/unmute restores level and simultaneous event/VS commit");$finish;
end
initial begin #100000;$fatal(1,"controls timeout");end
endmodule
