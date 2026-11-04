// Compact 64-glyph Chinese/number ROM. One synchronous read, same pixel latency as before.
module player_ui #(parameter VOICE=0,MAX_IMAGES=4,IMAGE_BITS=$clog2(MAX_IMAGES))(input wire clk,rst,input wire [IMAGE_BITS-1:0] image_index,input wire busy,auto_mode,
 input wire [1:0] brightness,input wire sound_enable,period_long,playing,failed,
 input wire [2:0] volume,input wire [7:0] error_code,input wire [9:0] x,y,
 input wire [23:0] rgb_in,output reg [23:0] rgb_out,input wire [4:0] image_count,input wire paused);
 reg [IMAGE_BITS-1:0] im,is;reg [4:0] count_m,count_s;
 wire [4:0] total=MAX_IMAGES==4?5'd4:count_s;
 wire [4:0] ordinal=total==0?5'd0:{1'b0,is}+1'b1;reg bm,bs,am,autos;reg [9:0] xq,yq;
 always @(posedge clk or posedge rst)begin
  if(rst)begin im<=0;is<=0;count_m<=0;count_s<=0;bm<=0;bs<=0;am<=0;autos<=0;xq<=0;yq<=0;end
  else begin im<=image_index;is<=im;count_m<=image_count;count_s<=count_m;bm<=busy;bs<=bm;am<=auto_mode;autos<=am;xq<=x;yq<=y;end
 end
 reg [15:0] font_rom[0:1023];reg [15:0] font_row;
 initial $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/player_zh_font.hex",font_rom);
 reg [5:0] glyph_id;reg [3:0] fy;reg text_on;reg [23:0] ink,ink_q;
 reg text_q;wire [5:0] ci=x[9:4]-6'd2;
 function [3:0] tens;input [4:0] n;begin tens=n>=20?2:n>=10?1:0;end endfunction
 function [3:0] units;input [4:0] n;begin units=n>=20?n-20:n>=10?n-10:n;end endfunction
 function [5:0] digit;input [3:0] n;begin digit=6'd6+n;end endfunction
 function [5:0] hex_digit;input [3:0] n;begin hex_digit=n<10?digit(n):6'd17+n-10;end endfunction
 always @*begin
  glyph_id=0;fy=0;text_on=0;ink=24'hf3f6fa;
  if(x>=32 && x<608)begin
   if(y>=24 && y<40)begin
    text_on=1;fy=y-24;
    case(ci)
       0:glyph_id=6'd1;
       1:glyph_id=6'd2;
       2:glyph_id=6'd3;
       3:glyph_id=6'd4;
       4:glyph_id=6'd50;
       5:glyph_id=6'd51;
       8:glyph_id=6'd23;
       9:glyph_id=6'd24;
       10:glyph_id=6'd25;
       11:glyph_id=6'd26;
     29:glyph_id=digit(tens(ordinal));30:glyph_id=digit(units(ordinal));31:glyph_id=6'd5;32:glyph_id=digit(tens(total));33:glyph_id=digit(units(total));
     default:glyph_id=0;
    endcase
    if(ci>=29)ink=24'h75d3c4;
   end else if(y>=50 && y<66)begin
    text_on=1;fy=y-50;ink=24'hb7c4d2;
    case(ci)
     0:glyph_id=autos?6'd27:6'd29;
       1:glyph_id=6'd28;
       2:glyph_id=6'd30;
       3:glyph_id=6'd31;
       6:glyph_id=6'd32;
       7:glyph_id=6'd33;
     8:glyph_id=digit(period_long?1:0);9:glyph_id=digit(period_long?0:5);
       10:glyph_id=6'd34;
       14:glyph_id=6'd35;
       15:glyph_id=6'd36;
     16:glyph_id=digit(brightness==3?1:0);
     17:case(brightness)0:glyph_id=digit(2);1:glyph_id=digit(5);2:glyph_id=digit(7);3:glyph_id=digit(0);endcase
     18:glyph_id=digit(brightness==0 || brightness==2?5:0);
     19:glyph_id=6'd16;
     26:glyph_id=failed?6'd42:bs?6'd37:6'd40;
     27:glyph_id=failed?6'd43:bs?6'd38:6'd41;
     28:glyph_id=failed?6'd21:bs?6'd39:0;
     29:glyph_id=failed?hex_digit(error_code[7:4]):0;
     30:glyph_id=failed?hex_digit(error_code[3:0]):0;
     default:glyph_id=0;
    endcase
    if(ci>=26)ink=failed?24'hff9e9e:bs?24'hefc68f:24'h75d3c4;
   end else if(y>=316 && y<332)begin
    text_on=1;fy=y-316;
    case(ci)
       0:glyph_id=6'd23;
       1:glyph_id=6'd24;
       2:glyph_id=6'd30;
       3:glyph_id=6'd31;
       15:glyph_id=6'd23;
       16:glyph_id=6'd47;
     18:glyph_id=digit(sound_enable && volume==4?1:0);
     19:case(sound_enable?volume:0)1:glyph_id=digit(2);2:glyph_id=digit(5);3:glyph_id=digit(7);default:glyph_id=digit(0);endcase
     20:glyph_id=digit(sound_enable && (volume==1 || volume==3)?5:0);
     21:glyph_id=6'd16;
     28:glyph_id=(VOICE && paused)?6'd48:!playing?6'd45:!sound_enable?6'd44:6'd30;
     29:glyph_id=(VOICE && paused)?6'd49:!playing?6'd46:!sound_enable?6'd23:6'd31;
     30:glyph_id=(VOICE && paused)?0:(!playing || sound_enable)?6'd39:0;
     default:glyph_id=0;
    endcase
    if(ci>=28)ink=(VOICE && paused)?24'hefc68f:sound_enable?24'h75d3c4:24'hb7c4d2;
   end
  end
 end
 always @(posedge clk)begin font_row<=font_rom[{glyph_id,fy}];ink_q<=ink;text_q<=text_on;end
 always @*begin
  rgb_out=rgb_in;
  if(xq>=16 && xq<624 && ((yq>=12 && yq<76)||(yq>=308 && yq<340)) &&
    !(((xq<18 || xq>=622) && (yq<16 || (yq>=72 && yq<76) || (yq>=308 && yq<312) || yq>=336)) ||
      ((xq<20 || xq>=620) && (yq<14 || (yq>=74 && yq<76) || (yq>=308 && yq<310) || yq>=338))))
   rgb_out={2'b0,rgb_in[23:18],2'b0,rgb_in[15:10],2'b0,rgb_in[7:2]}+24'h111d2b;
  if(xq>=440 && xq<548 && yq>=46 && yq<70 &&
    !((xq<442 || xq>=546)&&(yq<48 || yq>=68)))
   rgb_out=failed?24'h3a2634:bs?24'h3c3128:24'h1d3b3c;
  if(xq>=472 && xq<536 && yq>=312 && yq<336 &&
    !((xq<474 || xq>=534)&&(yq<314 || yq>=334)))
   rgb_out=(VOICE && paused)?24'h3c3128:24'h1d3b3c;
  if(xq>=32 && xq<80 && yq>=12 && yq<14)rgb_out=24'h75d3c4;
  if(text_q && font_row[15-xq[3:0]])rgb_out=ink_q;
 end
endmodule

