`timescale 1ns/1ps
module tb_chinese_title_stream;
 reg clk=0,mc=0,rst=1,vs=1,entry=0;reg [2:0] idx=0;reg [87:0] name=0;
 reg [9:0] x=0,y=0;wire [23:0] rgb;
 always #20 clk=~clk;always #7 mc=~mc;
 shell_overlay #(.LIBRARY(1)) d(.clk(clk),.rst(rst),.page(2'd1),.home_selected(2'd0),.settings_selected(2'd0),
  .brightness(2'd3),.sound_enable(1'b1),.period_long(1'b0),.playing(1'b1),.photo_ready(1'b1),.image_index(2'd0),.meter_levels(32'd0),
  .x(x),.y(y),.rgb_in(24'h123456),.rgb_out(rgb),.volume(3'd4),
  .catalog_clk(mc),.catalog_entry(entry),.catalog_type(1'b0),.catalog_index(idx),.catalog_name(name),
  .library_open(1'b1),.library_type(1'b0),.library_ready(1'b1),.library_cursor(3'd1),.library_count(4'd2),.vs(vs));
 integer xx,yy,i,checked=0;reg [2:0] flags=0;reg [1:0] a0=0,a1=0,a2=0;reg now_active;reg [1:0] now_alpha;
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(i=0;i<2;i=i+1)begin
   @(negedge mc);idx=i;name=i==0?"WEIYI   WAV":"ZAIJIAN WAV";entry=1;
   @(negedge mc);entry=0;repeat(32)@(negedge mc);
  end
  repeat(16)@(negedge clk);vs=0;repeat(8)@(negedge clk);vs=1;
  repeat(8)@(negedge clk);
  // One new pixel on every clock, crossing text/blank/row boundaries.
  for(yy=128;yy<258;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
   @(negedge clk);x=xx;y=yy;
   now_active=xx>=144 && xx<272 && ((yy>=152 && yy<168)||(yy>=216 && yy<232));
   now_alpha=0;
   if(now_active)now_alpha=(d.title_rom[2*((yy>=216?128:0)+xx-144)+(yy%64-24)/8]>>(14-((yy%64-24)%8)*2))&3;
   flags={flags[1:0],now_active};a2=a1;a1=a0;a0=now_alpha;
   @(posedge clk);#1;
   if(d.title_active_qq!==flags[2])$fatal(1,"stream title mask x=%0d y=%0d",xx,yy);
   if(flags[2])begin
    if(d.coverage!==a2)$fatal(1,"stream alpha x=%0d y=%0d got=%h expected=%h",xx,yy,d.coverage,a2);
    checked=checked+1;
   end
  end
  if(checked!=4096)$fatal(1,"coverage count %0d",checked);
  $display("PASS 83200 consecutive pixels, 4096 exact Chinese coverage pixels, text/blank/row boundaries, unchanged three-edge pipeline");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
