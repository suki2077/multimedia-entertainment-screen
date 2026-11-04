// Video transport and real media time, composited over the full-panel picture.
module video_hud(input wire [9:0] x,y,input wire [23:0] rgb_in,
 input wire paused,ready,failed,input wire [2:0] volume,input wire [9:0] progress,input wire [15:0] elapsed_bcd,total_bcd,output reg [23:0] rgb_out);
 function [34:0] number_glyph;input [3:0] d;begin case(d)
 0:number_glyph=35'b01110100011001110101110011000101110;
 1:number_glyph=35'b00100011000010000100001000010001110;
 2:number_glyph=35'b01110100010000100010001000100011111;
 3:number_glyph=35'b11110000010000101110000010000111110;
 4:number_glyph=35'b00010001100101010010111110001000010;
 5:number_glyph=35'b11111100001000011110000010000111110;
 6:number_glyph=35'b01110100001000011110100011000101110;
 7:number_glyph=35'b11111000010001000100010000100001000;
 8:number_glyph=35'b01110100011000101110100011000101110;
 9:number_glyph=35'b01110100011000101111000010000101110;
 default:number_glyph=0;endcase end endfunction
 reg [9:0] tx;reg [15:0] time_digits;reg [3:0] digit;reg [34:0] glyph;
 reg time_area;reg [3:0] gx,gy;integer i;
 wire [10:0] playhead=11'd64+{1'b0,progress};
 wire [10:0] px={1'b0,x};
 wire [23:0] glass={2'b0,rgb_in[23:18],2'b0,rgb_in[15:10],2'b0,rgb_in[7:2]}+24'h111d2b;
 always @*begin
  rgb_out=rgb_in;tx=0;time_digits=0;digit=0;glyph=0;gx=0;gy=0;time_area=0;
  if(y>=48 && y<62)begin
   if(x>=64 && x<124)begin tx=x-64;time_digits=elapsed_bcd;time_area=1;end
   else if(x>=516 && x<576)begin tx=x-516;time_digits=total_bcd;time_area=1;end
  end
  gx=(tx%12)>>1;gy=(y-48)>>1;
  case(tx/12)0:digit=time_digits[15:12];1:digit=time_digits[11:8];3:digit=time_digits[7:4];4:digit=time_digits[3:0];default:digit=15;endcase
  glyph=number_glyph(digit);
  if(x>=16 && x<624 && y>=12 && y<76 &&
    !(((x<18 || x>=622)&&(y<16 || y>=72)) || ((x<20 || x>=620)&&(y<14 || y>=74))))begin
   rgb_out=glass;
   if(y==12 || y==75)rgb_out=24'h334a60;
   if(y>=46 && y<64 && ((x>=60 && x<128)||(x>=512 && x<580)))rgb_out=24'h1a293a;
   if(x>=52 && x<60 && y>=26 && y<34)rgb_out=failed?24'he76b78:ready?24'h75d3c4:24'hefc68f;
   // Transport action: pause during playback; play while paused.
   if(!paused)begin
    if(((x>=28 && x<32)||(x>=37 && x<41)) && y>=23 && y<37)rgb_out=24'hefc68f;
   end else if(x>=28 && x<41 && y>=23 && y<37 && x-28<=(y<30?y-23:36-y)*2)rgb_out=24'h75d3c4;
   for(i=0;i<4;i=i+1)if(x>=516+i*20 && x<530+i*20 && y>=25 && y<35)rgb_out=i<volume?24'h75d3c4:24'h35485c;
  end
  // Timeline stays at the top; no HUD pixels are drawn over source subtitles.
  if(x>=64 && x<576 && y>=66 && y<71)begin
   rgb_out=24'h35485c;
   if(ready && x-64<progress)rgb_out=failed?24'he76b78:paused?24'hefc68f:24'h75d3c4;
   if(y==66 && ready && x-64<progress)rgb_out=paused?24'hffe7bc:24'hc4f3e9;
  end
  if(ready && y>=65 && y<72 &&
    ((y>=67 && y<70 && px+2>=playhead && px<=playhead+2) ||
     ((y==66 || y==70) && px+1>=playhead && px<=playhead+1)))
   rgb_out=paused?24'hffe7bc:24'hc4f3e9;
  if(time_area && ready)begin
   if((tx/12==2 && gx==2 && (gy==2 || gy==4)) || (gx<5 && gy<7 && glyph[34-(gy*5+gx)]))rgb_out=24'hf2f5f9;
  end
 end
endmodule

// Two PCM samples per FIFO word. Width512: (512*2)/(800 framesamples)=32/25.
// Bresenham remainder gives exact end-of-file progress, with no divider, DSP or frame RAM.
module video_progress(input wire clk,rst,input wire [14:0] total_frames,
 input wire word_consumed,output reg [9:0] pixels,output reg [15:0] elapsed_bcd,total_bcd);
 reg [14:0] length;reg [21:0] limit,remainder;
 function [15:0] next_second;input [15:0] t;reg [15:0] v;begin
  v=t;
  if(t[3:0]!=9)v[3:0]=t[3:0]+1'b1;
  else begin v[3:0]=0;
   if(t[7:4]!=5)v[7:4]=t[7:4]+1'b1;
   else begin v[7:4]=0;
    if(t[11:8]!=9)v[11:8]=t[11:8]+1'b1;
    else begin v[11:8]=0;v[15:12]=t[15:12]+1'b1;end
   end
  end
  next_second=v;
 end endfunction
 reg [13:0] second_words;reg [14:0] duration_left;
 // Slow metadata conversion: at most 1800 clocks (72 us), no combinational divider.
 always @(posedge clk or posedge rst)begin
  if(rst)begin elapsed_bcd<=0;total_bcd<=0;second_words<=0;duration_left<=0;end
  else if(length!=total_frames)begin
   elapsed_bcd<=0;total_bcd<=0;second_words<=0;duration_left<=total_frames;
  end else begin
   if(duration_left>=30)begin duration_left<=duration_left-30;total_bcd<=next_second(total_bcd);end
   if(word_consumed && limit!=0)begin
    if(pixels==512)begin elapsed_bcd<=0;second_words<=1;end
    else if(second_words==11999)begin second_words<=0;elapsed_bcd<=next_second(elapsed_bcd);end
    else second_words<=second_words+1'b1;
   end
  end
 end
 wire [21:0] sum=remainder+22'd32;
 wire [21:0] frame_limit={3'b0,total_frames,4'b0}+{4'b0,total_frames,3'b0}+{7'b0,total_frames};
 always @(posedge clk or posedge rst)begin
  if(rst)begin length<=0;limit<=0;remainder<=0;pixels<=0;end
  else if(length!=total_frames)begin
   length<=total_frames;limit<=frame_limit;remainder<=0;pixels<=0;
  end else if(word_consumed && limit!=0)begin
   if(pixels==512)begin pixels<=0;remainder<=32;end
   else if(sum>=limit)begin remainder<=sum-limit;pixels<=pixels+1'b1;end
   else remainder<=sum;
  end
 end
endmodule
