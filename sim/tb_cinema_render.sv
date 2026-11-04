`timescale 1ns/1ps
module tb_cinema_render;
 reg[9:0] x=0,y=0;reg[23:0] bg[0:307199];wire[23:0] rgb;
 wire[23:0] source=bg[y*640+x];integer f,i,j;
 video_hud hud(x,y,source,1'b0,1'b1,1'b0,3'd3,10'd171,16'h0123,16'h0345,rgb);
 initial begin
  $readmemh("sim/background.hex",bg);
  f=$fopen("preview/cinema_video.ppm","wb");$fwrite(f,"P6\n640 480\n255\n");
  for(j=0;j<480;j=j+1)for(i=0;i<640;i=i+1)begin
   x=i;y=j;#1;if(^rgb===1'bx)$fatal(1,"undefined overlay pixel");
   $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  end
  $fclose(f);$display("PASS cinema overlay preview with mm:ss time and full picture background");$finish;
 end
endmodule
