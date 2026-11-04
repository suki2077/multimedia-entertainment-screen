`timescale 1ns/1ps
module tb_top_hud;
 reg clk=0,rst=1,video_mode=1;always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg paused=0;wire [23:0] hud,caption;
 reg [23:0] base=24'h93c465;integer xx,yy,f;wire tx;wire[7:0] td;
 video_hud h(x,y,base,paused,1'b1,1'b0,3'd3,10'd256,16'h0123,16'h0345,hud);
 subtitle_overlay sub(.clk(clk),.rst(rst),.vs(1'b1),.rx_valid(1'b0),.rx_error(1'b0),.rx_data(8'd0),
 .tx_valid(tx),.tx_data(td),.tx_ready(1'b1),.x(x),.y(video_mode?10'd0:y),.rgb_in(hud),.rgb_out(caption));
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
   @(negedge clk);x=xx;y=yy;@(posedge clk);#1;
   if(^caption===1'bx)$fatal(1,"undefined output");
   if(yy>=76 && caption!==base)$fatal(1,"HUD or marquee covers source at %0d,%0d",xx,yy);
  end
  @(negedge clk);x=100;y=68;#1;if(hud!==24'h58dfc0)$fatal(1,"top track fill");
  x=500;#1;if(hud!==24'h2b3e53)$fatal(1,"top track remainder");
  x=100;paused=1;#1;if(hud!==24'hecbb86)$fatal(1,"paused track");
  @(negedge clk);video_mode=0;x=30;y=450;repeat(3)@(posedge clk);#1;
  if(caption===base)$fatal(1,"album marquee missing");
  $display("PASS top controls/time/track and complete lower-frame passthrough, including embedded-caption region; custom album marquee retained");$finish;
 end
endmodule
