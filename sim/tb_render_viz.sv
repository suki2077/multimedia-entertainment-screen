`timescale 1ns/1ps
module tb_render_viz;
 reg clk=0,rst=1,vs=1,audio_valid=0;
 reg [23:0] pcm=0;
 reg [9:0] x=0,y=0;
 wire [23:0] rgb_out;
 integer i,j,f,amp;
 audio_wave_overlay dut(clk,rst,vs,audio_valid,pcm,x,y,24'h182c40,rgb_out);
 always #5 clk=~clk;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(i=0;i<768;i=i+1)begin
   amp=2+(((i/24)*7)%15);
   @(negedge clk);pcm=amp<<19;audio_valid=1;
   @(negedge clk);audio_valid=0;
  end
  @(negedge clk);vs=0;
  @(negedge clk);vs=1;
  f=$fopen("preview/audio_viz.ppm","w");
  $fwrite(f,"P3\n640 96\n255\n");
  for(j=360;j<456;j=j+1)begin
   for(i=0;i<640;i=i+1)begin
    @(negedge clk);x=i;y=j;
    repeat(2)@(posedge clk);#1;
    $fwrite(f,"%0d %0d %0d\n",rgb_out[23:16],rgb_out[15:8],rgb_out[7:0]);
   end
  end
  $fclose(f);$display("PASS RTL preview rendered");$finish;
 end
endmodule
