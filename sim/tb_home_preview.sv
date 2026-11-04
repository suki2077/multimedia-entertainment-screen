`timescale 1ns/1ps
module tb_home_preview;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [9:0] x=0,y=0;wire [23:0] rgb;reg [23:0] background[0:307199];integer i,j,fd;
 wire [23:0] image_rgb=background[y*640+x];
 shell_overlay d(clk,rst,2'd0,2'd3,2'd0,2'd3,1'b1,1'b0,1'b1,1'b1,2'd0,32'h98765432,x,y,image_rgb,rgb,3'd3,1'b0,1'b0,1'b0,3'd0,88'd0,1'b0,1'b0,1'b0,3'd0,4'd0,1'b1,5'd4,1'b0);
 initial begin
  $readmemh("sim/background.hex",background);repeat(4)@(negedge clk);rst=0;
  fd=$fopen("preview/console_home.ppm","wb");$fwrite(fd,"P6\n640 480\n255\n");
  for(j=0;j<480;j=j+1)for(i=0;i<640;i=i+1)begin
   @(negedge clk);x=i;y=j;repeat(4)@(posedge clk);#1;$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  end
  $fclose(fd);$display("PASS home preview rendered");$finish;
 end
endmodule
