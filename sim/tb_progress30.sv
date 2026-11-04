`timescale 1ns/1ps
module tb_progress30;
 reg clk=0,rst=1,pop=0;always #5 clk=~clk;
 reg [14:0] total=60;wire [9:0] pixels;wire [15:0] elapsed,duration;
 video_progress dut(clk,rst,total,pop,pixels,elapsed,duration);
 integer i;
 initial begin
  repeat(4)@(negedge clk);rst=0;repeat(10)@(negedge clk);
  if(duration!==16'h0002)$fatal(1,"duration 60 frames must be 2s");
  for(i=0;i<24000;i=i+1)begin
   pop=1;@(negedge clk);pop=0;@(negedge clk);
   if(i==11999 && elapsed!==16'h0001)$fatal(1,"elapsed 1s");
  end
  if(pixels!==512 || elapsed!==16'h0002)$fatal(1,"progress end %d %h",pixels,elapsed);
  pop=1;@(negedge clk);pop=0;@(negedge clk);
  if(pixels!==0 || elapsed!==0)$fatal(1,"EOF reset");
  total=32513;repeat(1700)@(negedge clk);
  if(duration!==16'h1803 || dut.limit!==812825)$fatal(1,"maximum duration/progress overflow %h %d",duration,dut.limit);
  $display("PASS 30fps progress, PCM elapsed time, EOF reset, maximum FAT32 duration and wide arithmetic");$finish;
 end
endmodule
