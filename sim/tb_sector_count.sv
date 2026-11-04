`timescale 1ns/1ps
module tb_sector_count;
 reg clk=0,rst=1,v=0;always #7 clk=~clk;
 wire mf,bf;wire [7:0] me,be;
 fat32_media_stream media(.clk(clk),.rst(rst),.enable(1'b0),.sd_ready(1'b0),.io_wait(1'b0),.video_mode(1'b0),
  .byte_valid(1'b0),.byte_data(8'd0),.sector_end(1'b0),.sample_ready(1'b0),.failed(mf),.error_code(me));
 fat32_bmp_loader bmp(.clk(clk),.rst(rst),.enable(1'b0),.sd_ready(1'b0),.io_wait(1'b0),.image_index(2'd0),
  .byte_valid(1'b0),.byte_data(8'd0),.sector_end(1'b0),.group_ready(1'b0),.failed(bf),.error_code(be));
 integer n,k,expected;
 initial begin
  force media.rx_valid=v;force media.rx_end=1'b1;force bmp.rx_valid=v;force bmp.rx_end=1'b1;
  for(n=0;n<1024;n=n+1)for(k=0;k<2;k=k+1)begin
   @(negedge clk);rst=1;@(negedge clk);rst=0;v=k;
   media.state=1;media.return_state=2;media.received=n;
   bmp.state=1;bmp.return_state=2;bmp.received=n;
   expected=(n+k==512);
   @(posedge clk);#1;
   if(expected)begin if(mf || bf || media.state!=2 || bmp.state!=2)$fatal(1,"valid end rejected n=%0d v=%0d",n,k);end
   else if(!mf || !bf || me!=2 || be!=2)$fatal(1,"short/overlong end accepted n=%0d v=%0d",n,k);
  end
  $display("PASS exhaustive sector-end truth table: 2048 count/last-byte cases for both WAV/video and BMP readers, no extra cycle");$finish;
 end
 initial begin #1000000;$fatal(1,"count timeout");end
endmodule
