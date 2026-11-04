`timescale 1ns/1ps
module tb_zhprogress;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,consume=0;reg[14:0] frames=0;wire[9:0] pixels;
 wire [15:0] elapsed,total;
 video_progress prog(clk,rst,frames,consume,pixels,elapsed,total);
 reg[9:0] x=0,y=0;wire[23:0] rgb;reg[1:0] brightness=0,image_index=0;
 reg busy=0,auto_mode=0,sound=1,period_long=0,playing=1,failed=0;reg[2:0] volume=3;
 player_ui ui(clk,rst,image_index,busy,auto_mode,brightness,sound,period_long,playing,failed,volume,8'hab,x,y,24'h204060,rgb,5'd4);
 wire[23:0] hud;reg paused=0;reg[9:0] bar=256;
 video_hud vh(x,y,24'h123456,paused,1'b1,1'b0,3'd3,bar,elapsed,total,hud);
 task check_progress;input integer n;integer k,expected;begin
  @(negedge clk);frames=n;consume=0;@(posedge clk);#1;
  if(pixels!==0)$fatal(1,"length change did not reset");
  for(k=1;k<=800*n;k=k+1)begin
   @(negedge clk);consume=1;@(posedge clk);#1;expected=(64'd512*k)/(800*n);
   if(pixels!==expected)$fatal(1,"N=%0d word=%0d expected=%0d actual=%0d",n,k,expected,pixels);
   if(k%100003==0 || k==400*n)begin
    @(negedge clk);consume=0;repeat(7)begin @(posedge clk);#1;if(pixels!==expected)$fatal(1,"pause drift");end
   end
  end
  if(n==27000 && (elapsed!==16'h3000 || total!==16'h3000))$fatal(1,"30-minute duration mismatch elapsed=%h total=%h",elapsed,total);
  @(negedge clk);consume=1;@(posedge clk);#1;if(pixels!==0 || elapsed!==0)$fatal(1,"loop reset");
  @(negedge clk);consume=0;
 end endtask
 task char_check;input integer px,py,g;integer row,col;reg[23:0] wanted;begin
  for(row=0;row<16;row=row+1)for(col=0;col<16;col=col+1)begin
   @(negedge clk);x=px+col;y=py+row;#1;
   if(ui.glyph_id!==g)$fatal(1,"glyph wrong at %0d,%0d expected %0d actual %0d",x,y,g,ui.glyph_id);
   @(posedge clk);#1;
   wanted=ui.font_rom[g*16+row][15-col]?ui.ink_q:24'h14273e;
   if(rgb!==wanted)$fatal(1,"pixel alignment at %0d,%0d expected %h actual %h",x,y,wanted,rgb);
  end
 end endtask
 integer f,xx,yy;
 initial begin
  repeat(3)@(posedge clk);@(negedge clk);rst=0;repeat(3)@(posedge clk);
  // Character IDs are checked from the versioned, bounded font dictionary.
  char_check(32,24,1); // SUKI S
  char_check(256,50,35); // brightness label, validated against glyph map by runner
  check_progress(1);check_progress(15);check_progress(27000);
  @(negedge clk);x=100;y=68;#1;if(hud!==24'h58dfc0)$fatal(1,"filled progress pixel");
  x=500;#1;if(hud!==24'h2b3e53)$fatal(1,"unfilled progress pixel");
  x=100;paused=1;#1;if(hud!==24'hecbb86)$fatal(1,"paused progress pixel");
  y=420;#1;if(hud!==24'h123456)$fatal(1,"subtitle overlap");
  if($test$plusargs("RENDER"))begin
   f=$fopen("preview/chinese_player.ppm","w");$fwrite(f,"P3\n640 480\n255\n");
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;@(posedge clk);#1;
    $fwrite(f,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
   end
   $fclose(f);
  end
  $display("PASS Chinese glyph alignment; exact progress N=1,15,27000; 30:00 elapsed/total, pause/loop and subtitle region");$finish;
 end
endmodule
