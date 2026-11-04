`timescale 1ns/1ps
module tb_photo_clean_label;
reg clk=0,rst=1;always #5 clk=~clk;reg clean=1;reg[9:0] x=0,y=0;wire[23:0] rgb;
shell_overlay #(.LIBRARY(1),.MAX_IMAGES(20),.PHOTO_CLEAN(1)) d(.clk(clk),.rst(rst),.page(2'd3),.home_selected(2'd0),.settings_selected(2'd3),.brightness(2'd3),.sound_enable(1'b1),.period_long(1'b0),.playing(1'b1),.photo_ready(1'b1),.image_index(5'd0),.image_count(5'd20),.meter_levels(32'd0),.x(x),.y(y),.rgb_in(24'd0),.rgb_out(rgb),.volume(3'd4),.catalog_clk(clk),.catalog_entry(1'b0),.catalog_type(1'b0),.catalog_index(3'd0),.catalog_name(88'd0),.library_open(1'b0),.library_type(1'b0),.library_ready(1'b1),.library_cursor(3'd0),.library_count(4'd2),.vs(1'b1),.clean_photo(clean));
integer i,j,f;initial begin repeat(5)@(negedge clk);rst=0;repeat(20)@(negedge clk);f=$fopen("preview/photo_clean_toggle.ppm","w");$fwrite(f,"P3\n640 64\n255\n");
for(j=326;j<390;j=j+1)for(i=0;i<640;i=i+1)begin @(negedge clk);x=i;y=j;@(posedge clk);#1;if(^rgb===1'bx)$fatal(1,"unknown pixel");if(j==356 && i==574 && rgb!==24'h66dfbd)$fatal(1,"ON switch color");$fwrite(f,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);end
$fclose(f);clean=0;x=546;y=356;repeat(10)@(negedge clk);if(rgb!==24'h7893a8)$fatal(1,"OFF switch color");$display("PASS reused Chinese photo-mode label and switch preview, all pixels known");$finish;end
endmodule
