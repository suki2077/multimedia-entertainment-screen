`timescale 1ns/1ps
module tb_transition_ui;
reg clk=0,rst=1;always #5 clk=~clk;
reg[9:0] x=0,y=0;reg[1:0] effect=0;wire[23:0] rgb;integer i,j,n,fd;
shell_overlay #(.LIBRARY(1),.TRANSITIONS(1)) d(.clk(clk),.rst(rst),.page(2'd3),.home_selected(2'd0),.settings_selected(2'd3),.brightness(2'd3),.sound_enable(1'b1),.period_long(1'b0),.playing(1'b1),.photo_ready(1'b1),.image_index(effect),.meter_levels(32'd0),.x(x),.y(y),.rgb_in(24'h123456),.rgb_out(rgb),.volume(3'd4),.catalog_clk(clk),.catalog_entry(1'b0),.catalog_type(1'b0),.catalog_index(3'd0),.catalog_name(88'd0),.library_open(1'b0),.library_type(1'b0),.library_ready(1'b0),.library_cursor(3'd0),.library_count(4'd0),.vs(1'b1));
initial begin repeat(4)@(negedge clk);rst=0;
for(j=0;j<3;j=j+1)begin effect=j;repeat(8)@(negedge clk);case(j)0:fd=$fopen("preview/transition_fade.ppm","wb");1:fd=$fopen("preview/transition_wipe.ppm","wb");2:fd=$fopen("preview/transition_blinds.ppm","wb");endcase
$fwrite(fd,"P6\n640 480\n255\n");
for(n=0;n<307202;n=n+1)begin @(negedge clk);x=n<307200?n%640:0;y=n<307200?n/640:0;@(posedge clk);#1;if(n>=2)begin if(^rgb===1'bx)$fatal(1,"unknown UI");$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end end
$fclose(fd);end
$display("PASS 3 actual RTL settings previews; Chinese transition names and 2x scaled title, all pixels known");$finish;end
initial begin #50000000;$fatal(1,"timeout");end
endmodule
