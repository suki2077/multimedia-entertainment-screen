`timescale 1ns/1ps
module tb_progress20;
 reg clk=0,rst=1,pop=0;always #5 clk=~clk;
 reg [14:0] total=40;wire [9:0] pixels;wire [15:0] elapsed,duration;
 video_progress dut(clk,rst,total,pop,pixels,elapsed,duration);
 integer i;
 initial begin
  repeat(4)@(negedge clk);rst=0;repeat(10)@(negedge clk);
  if(duration!==16'h0002)$fatal(1,"duration 40 frames must be 2s");
  for(i=0;i<24000;i=i+1)begin
   pop=1;@(negedge clk);pop=0;@(negedge clk);
   if(i==11999 && elapsed!==16'h0001)$fatal(1,"elapsed 1s");
  end
  if(pixels!==512 || elapsed!==16'h0002)$fatal(1,"progress end %d %h",pixels,elapsed);
  pop=1;@(negedge clk);pop=0;@(negedge clk);
  if(pixels!==0 || elapsed!==0)$fatal(1,"EOF reset");
  total=32388;repeat(1700)@(negedge clk);
  if(duration!==16'h2659 || dut.limit!==2429100)$fatal(1,"maximum duration/progress overflow %h %d",duration,dut.limit);
  $display("PASS 20fps progress, PCM elapsed time, EOF reset, maximum FAT32 duration and wide arithmetic");$finish;
 end
endmodule
