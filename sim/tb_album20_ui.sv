`timescale 1ns/1ps
module tb_album20_ui;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [4:0] image=0,total=20;reg [9:0] x=0,y=0;wire [23:0] rgb,home;
 player_ui #(.MAX_IMAGES(20)) p(.clk(clk),.rst(rst),.image_index(image),.image_count(total),.busy(1'b0),.auto_mode(1'b1),
 .brightness(2'd3),.sound_enable(1'b1),.period_long(1'b0),.playing(1'b1),.failed(1'b0),.volume(3'd4),.error_code(8'd0),.x(x),.y(y),.rgb_in(24'h19303d),.rgb_out(rgb));
 shell_overlay #(.MAX_IMAGES(20)) h(.clk(clk),.rst(rst),.page(2'd0),.home_selected(2'd0),.settings_selected(2'd0),.brightness(2'd3),.sound_enable(1'b1),
 .period_long(1'b0),.playing(1'b1),.photo_ready(1'b1),.image_index(image),.image_count(total),.meter_levels(32'd0),.x(x),.y(y),.rgb_in(24'h19303d),.rgb_out(home),.volume(3'd4),
 .catalog_clk(clk),.catalog_entry(1'b0),.catalog_type(1'b0),.catalog_index(3'd0),.catalog_name(88'd0),.library_open(1'b0),.library_type(1'b0),.library_ready(1'b0),.library_cursor(3'd0),.library_count(4'd0),.vs(1'b1));
 integer n,c,number,wanted,col,fd,xx,yy;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(n=0;n<20;n=n+1)begin
   image=n;repeat(8)@(negedge clk);
   for(c=0;c<4;c=c+1)begin
    number=c<2?n+1:20;wanted=c%2==0?number/10:number%10;
    col=c<2?29+c:30+c;
    x=32+col*16;y=24;repeat(4)@(negedge clk);
    if(p.glyph_id!==6+wanted)$fatal(1,"player counter image=%d column=%d glyph=%d expected=%d",n,c,p.glyph_id,6+wanted);
    col=c<2?c:c+3;x=316+col*8;y=320;repeat(4)@(negedge clk);
    if(!h.photo_digit || h.photo_char!==48+wanted || h.small_glyph!==h.library_glyph(48+wanted))$fatal(1,"home counter image=%d column=%d char=%h",n,c,h.photo_char);
   end
  end
  total=0;image=0;repeat(8)@(negedge clk);x=512;y=24;repeat(4)@(negedge clk);if(p.glyph_id!=6)$fatal(1,"empty 00/00");
  total=20;image=19;repeat(8)@(negedge clk);
  fd=$fopen("preview/album20_header.ppm","wb");$fwrite(fd,"P6\n640 96\n255\n");
  for(yy=0;yy<96;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
   x=xx;y=yy;repeat(4)@(negedge clk);if(^rgb===1'bx)$fatal(1,"unknown UI pixel");$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  end
  $fclose(fd);
  $display("PASS home and photo counter 01..20/20, decimal 09/10 and 19/20 boundaries, empty 00/00 and actual RTL header preview");$finish;
 end
 initial begin #100000000;$fatal(1,"UI timeout");end
endmodule
