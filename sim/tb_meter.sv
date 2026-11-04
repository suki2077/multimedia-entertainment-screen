`timescale 1ns/1ps
module tb_meter;
reg clk=0,rst=1,vs=1,av=0,sound=1,playing=1;reg[23:0] pcm=0;wire[31:0] levels;
always #5 clk=~clk;
home_audio_meter d(clk,rst,vs,av,pcm,sound,playing,levels);
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task sample(input[23:0] p);begin pcm=p;av=1;ticks(1);av=0;ticks(2);end endtask
task frame;begin vs=0;ticks(1);vs=1;ticks(2);end endtask
integer i;
initial begin
ticks(3);rst=0;ticks(3);sample(24'h400000);sample(24'h200000);
if(levels!=0)$fatal(1,"meter published during active frame");frame();if(levels!=8)$fatal(1,"peak detection");
sample(24'h800000);frame();if(levels!=32'h8f)$fatal(1,"negative full-scale overflow");
pcm=24'h7fffff;av=1;vs=0;ticks(1);vs=1;av=0;ticks(2);
if(levels!=32'h8ff)$fatal(1,"positive saturation or boundary sample lost");
for(i=0;i<8;i=i+1)frame();if(levels!=0)$fatal(1,"silence manufactured animation");
sample(24'hf00000);frame();if(levels[3:0]!=2)$fatal(1,"negative magnitude");
sound=0;ticks(1);if(levels!=0)$fatal(1,"mute history visible");sample(24'h7fffff);frame();if(levels!=0)$fatal(1,"mute still animating");
sound=1;playing=0;sample(24'h7fffff);frame();if(levels!=0)$fatal(1,"buffering still animating");
playing=1;sample(24'h300000);frame();if(levels!=6)$fatal(1,"resume peak");
$display("PASS actual PCM peak meter: signs/full scale, frame-only publication, boundary sample, history shift, silence/mute/buffering cleared, resume");$finish;
end
endmodule
