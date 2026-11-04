// Multimedia game screen: live cropped cover, native-size antialiased type, actual PCM meter.
// Two extra pixel stages; top-level HS/VS/DE delay must match. Page 1 preserves RGB.
module shell_overlay #(parameter LIBRARY=0,TRANSITIONS=0,PHOTO_CLEAN=0,MAX_IMAGES=4,IMAGE_BITS=$clog2(MAX_IMAGES))(input wire clk,rst,input wire [1:0] page,home_selected,settings_selected,
 input wire [1:0] brightness,input wire sound_enable,period_long,playing,photo_ready,
 input wire [IMAGE_BITS-1:0] image_index,input wire [31:0] meter_levels,
 input wire [9:0] x,y,input wire [23:0] rgb_in,output reg [23:0] rgb_out,input wire [2:0] volume,
 input wire catalog_clk,catalog_entry,catalog_type,input wire [2:0] catalog_index,
 input wire [87:0] catalog_name,input wire library_open,library_type,library_ready,
 input wire [2:0] library_cursor,input wire [3:0] library_count,input wire vs,input wire [4:0] image_count,input wire clean_photo);
 // Reuse character RAM: static UI strings in 0..383, 16 short basenames
 // in 384..511. One shared read port, no additional physical RAM.
 reg [7:0] char_rom[0:511];reg [63:0] write_name;reg [3:0] write_slot;
 reg [2:0] write_phase;reg write_busy;
 // Preset display aliases. The actual FAT short name and file selection stay intact.
 // Slot zero's OEM Chinese short name is the user's existing first song.
 function [1:0] preset_title;input [87:0] n;input [2:0] slot;begin
  if(n[23:0]!=24'h574156)preset_title=0;
  else if(n[87:24]=="ZAIJIAN ")preset_title=2;
  else if(n[87:24]=="WEIYI   " || n[87:24]=="MUSIC   " || (slot==0 && n[87]))preset_title=1;
  else preset_title=0;
 end endfunction
 // A marker in the existing basename RAM selects the two preset strips.
 // Prefetch it in the left margin, before the filename starts at x=144.
 reg vs_q;reg [1:0] row_title;
 reg [7:0] char_q;wire list_open,list_type;
 always @(posedge clk or posedge rst)begin
  if(rst)row_title<=0;
  else if(LIBRARY && list_open && x==128 && y>=128 && y<384)
   row_title<=(!list_type && (char_q==1 || char_q==2))?char_q[1:0]:2'd0;
 end
 wire [9:0] source={library_open,library_type,library_ready,library_cursor,library_count};
 reg [9:0] source_saved;reg source_event;
 always @(posedge catalog_clk or posedge rst)begin
  if(rst)begin write_busy<=0;write_phase<=0;write_name<=0;write_slot<=0;source_saved<=0;source_event<=0;end
  else if(LIBRARY)begin
   if(source!=source_saved)begin source_saved<=source;source_event<=~source_event;end
   if(catalog_entry)begin write_name<=(!catalog_type && preset_title(catalog_name,catalog_index)!=0)?
    {6'd0,preset_title(catalog_name,catalog_index),catalog_name[79:24]}:catalog_name[87:24];write_slot<={catalog_type,catalog_index};write_phase<=0;write_busy<=1;end
   else if(write_busy)begin
    write_name<={write_name[55:0],8'd0};
    if(write_phase==7)write_busy<=0;else write_phase<=write_phase+1'b1;
   end
  end
 end
 always @(posedge catalog_clk)if(LIBRARY && write_busy)begin
  char_rom[{2'b11,write_slot,write_phase}]<=write_name[63:56];
 end
 reg [9:0] source_meta,source_data,pending_state,visible_state;
 reg [2:0] event_pipe;reg event_seen,have_pending;
 wire new_event=event_pipe[2]!=event_seen;
 always @(posedge clk or posedge rst)begin
  if(rst)begin source_meta<=0;source_data<=0;pending_state<=0;visible_state<=0;event_pipe<=0;event_seen<=0;have_pending<=0;vs_q<=1;end
  else if(LIBRARY)begin
   source_meta<=source_saved;source_data<=source_meta;event_pipe<={event_pipe[1:0],source_event};vs_q<=vs;
   if(new_event)begin event_seen<=event_pipe[2];pending_state<=source_data;have_pending<=1;end
   if(vs_q && !vs && (have_pending || new_event))begin visible_state<=new_event?source_data:pending_state;have_pending<=0;end
  end
 end
 assign list_open=LIBRARY && visible_state[9];assign list_type=visible_state[8];wire list_ready=visible_state[7];
 wire [2:0] list_cursor=visible_state[6:4];wire [3:0] list_count=visible_state[3:0];
 wire [9:0] list_y=y-10'd128;
 wire [2:0] list_index={list_cursor[2],list_y[7:6]};
 wire [9:0] name_dx=x-10'd144;
 wire [1:0] title_kind=(LIBRARY && !list_type)?row_title:2'd0;
 reg [1:0] title_kind_q;
 always @(posedge clk)title_kind_q<=title_kind;
 reg file_text,number_text;reg [3:0] filename_column_q;reg filename_type_q;
 reg file_q,number_q;reg [2:0] index_q;
 always @(posedge clk)begin
  filename_column_q<=name_dx[7:4];filename_type_q<=list_type;
  file_q<=file_text;number_q<=number_text;index_q<=list_index;
 end

 reg list_q;reg [11:0] font_index[0:2047];reg [31:0] font_dictionary[0:1023];
 initial begin
  if(PHOTO_CLEAN)begin
   $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/font_photo_smooth_index.hex",font_index);
   $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/font_photo_smooth_dictionary.hex",font_dictionary);
  end else begin
   $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/font_smooth_index.hex",font_index);
   $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/font_smooth_dictionary.hex",font_dictionary);
  end
 end
 function [14:0] text_span;input [5:0] id;begin case(id)
  6'd0:text_span={9'd0,6'd4};
  6'd1:text_span={9'd4,6'd10};
  6'd2:text_span={9'd14,6'd8};
  6'd3:text_span={9'd22,6'd6};
  6'd4:text_span={9'd28,6'd4};
  6'd5:text_span={9'd0,6'd0};
  6'd6:text_span={9'd0,6'd0};
  6'd7:text_span={9'd32,6'd10};
  6'd8:text_span={9'd42,6'd11};
  6'd9:text_span={9'd53,6'd14};
  6'd10:text_span={9'd0,6'd0};
  6'd11:text_span={9'd0,6'd0};
  6'd12:text_span={9'd0,6'd0};
  6'd13:text_span={9'd67,6'd8};
  6'd14:text_span={9'd0,6'd0};
  6'd15:text_span={9'd0,6'd0};
  6'd16:text_span={9'd75,6'd8};
  6'd17:text_span={9'd83,6'd4};
  6'd18:text_span={9'd87,6'd8};
  6'd19:text_span={9'd95,6'd8};
  6'd20:text_span={9'd103,6'd3};
  6'd21:text_span={9'd106,6'd3};
  6'd22:text_span={9'd109,6'd3};
  6'd23:text_span={9'd112,6'd4};
  6'd24:text_span={9'd0,6'd0};
  6'd25:text_span={9'd0,6'd0};
  6'd26:text_span={9'd116,6'd3};
  6'd27:text_span={9'd119,6'd4};
  6'd28:text_span={9'd123,6'd9};
  6'd29:text_span={9'd132,6'd23};
  6'd30:text_span={9'd155,6'd18};
  6'd31:text_span={9'd0,6'd0};
  6'd32:text_span={9'd0,6'd0};
  6'd33:text_span={9'd0,6'd0};
  6'd34:text_span={9'd173,6'd12};
  6'd35:text_span={9'd185,6'd12};
  6'd36:text_span={9'd197,6'd7};
  6'd37:text_span={9'd204,6'd7};
  6'd38:text_span={9'd0,6'd0};
  6'd39:text_span={9'd211,6'd7};
  6'd40:text_span={9'd218,6'd9};
  6'd41:text_span={9'd227,6'd2};
  6'd42:text_span={9'd229,6'd8};
  6'd43:text_span={9'd237,6'd8};
  6'd44:text_span={9'd245,6'd8};
  6'd45:text_span={9'd253,6'd8};
  6'd46:text_span={9'd261,6'd11};
  6'd47:text_span={9'd272,6'd8};
  6'd48:text_span={9'd280,6'd5};
  6'd49:text_span={9'd285,6'd5};
  6'd50:text_span={9'd290,6'd8};
  6'd51:text_span={9'd298,6'd8};
  6'd52:text_span={9'd306,6'd4};
  6'd53:text_span={9'd310,6'd6};
  6'd54:text_span={9'd316,6'd8};
 default:text_span=0;endcase end endfunction

 function [6:0] large_info;input [5:0] id;input [3:0] character;input [1:0] quadrant;begin case({id,character})
  10'd0:large_info=7'd91+quadrant;
  10'd1:large_info=7'd95+quadrant;
  10'd2:large_info=7'd99+quadrant;
  10'd3:large_info=7'd103+quadrant;
  10'd48:large_info=7'd107+quadrant;
  10'd49:large_info=7'd111+quadrant;
  10'd50:large_info=7'd115+quadrant;
  10'd64:large_info=7'd119+quadrant;
  10'd65:large_info=7'd123+quadrant;
  default:large_info=0;endcase end endfunction

 function [7:0] library_glyph;input [7:0] c;begin case(c)
  8'd65:library_glyph=8'd40;
  8'd66:library_glyph=8'd44;
  8'd67:library_glyph=8'd50;
  8'd68:library_glyph=8'd62;
  8'd69:library_glyph=8'd26;
  8'd70:library_glyph=8'd64;
  8'd71:library_glyph=8'd70;
  8'd72:library_glyph=8'd82;
  8'd73:library_glyph=8'd28;
  8'd74:library_glyph=8'd88;
  8'd75:library_glyph=8'd30;
  8'd76:library_glyph=8'd96;
  8'd77:library_glyph=8'd98;
  8'd78:library_glyph=8'd124;
  8'd79:library_glyph=8'd158;
  8'd80:library_glyph=8'd176;
  8'd81:library_glyph=8'd214;
  8'd82:library_glyph=8'd216;
  8'd83:library_glyph=8'd34;
  8'd84:library_glyph=8'd218;
  8'd85:library_glyph=8'd36;
  8'd86:library_glyph=8'd220;
  8'd87:library_glyph=8'd222;
  8'd88:library_glyph=8'd224;
  8'd89:library_glyph=8'd42;
  8'd90:library_glyph=8'd226;
  8'd48:library_glyph=8'd8;
  8'd49:library_glyph=8'd10;
  8'd50:library_glyph=8'd12;
  8'd51:library_glyph=8'd14;
  8'd52:library_glyph=8'd16;
  8'd53:library_glyph=8'd18;
  8'd54:library_glyph=8'd228;
  8'd55:library_glyph=8'd20;
  8'd56:library_glyph=8'd230;
  8'd57:library_glyph=8'd232;
  8'd32:library_glyph=8'd0;
  8'd46:library_glyph=8'd234;
  8'd95:library_glyph=8'd236;
  default:library_glyph=8'd236;endcase end endfunction

 reg text_area,font_big;reg [5:0] line_id;reg [9:0] origin_x,origin_y;
 wire [9:0] dx=x-origin_x,dy=y-origin_y;reg [23:0] text_color;
 task place_text;
  input [9:0] px,py;input [5:0] id;input [9:0] left,top,width;input big;input [23:0] color;
  begin
   if(px>=left && px<left+width && py>=top && py<top+(big?32:16))begin
    text_area=1;line_id=id;origin_x=left;origin_y=top;font_big=big;text_color=color;
   end
  end
 endtask
 reg [IMAGE_BITS-1:0] image_index_meta,image_index_sync;reg [4:0] count_meta,count_sync;
 always @(posedge clk or posedge rst)begin
  if(rst)begin image_index_meta<=0;image_index_sync<=0;count_meta<=0;count_sync<=0;end
  else begin image_index_meta<=image_index;image_index_sync<=image_index_meta;count_meta<=image_count;count_sync<=count_meta;end
 end
 always @*begin
  text_area=0;line_id=0;origin_x=0;origin_y=0;font_big=0;text_color=24'hf2f5f9;file_text=0;number_text=0;
  case(page)
   0:begin
   place_text(x,y,6'd0,10'd28,10'd24,10'd128,1'b1,24'hf2f5f9);
   place_text(x,y,6'd1,10'd166,10'd40,10'd80,1'b0,24'ha2afc0);
   if(home_selected==2)begin
   place_text(x,y,6'd4,10'd562,10'd38,10'd32,1'b0,24'h102c30);
   end else begin
   place_text(x,y,6'd4,10'd562,10'd38,10'd32,1'b0,24'ha2afc0);
   end
   place_text(x,y,6'd2,10'd52,10'd318,10'd64,1'b0,24'hf2f5f9);
   place_text(x,y,6'd35,10'd52,10'd350,10'd96,1'b0,24'ha2afc0);
   if(MAX_IMAGES>4)place_text(x,y,6'd36,10'd316,10'd318,10'd56,1'b0,24'ha2afc0);
   else begin
   case(image_index_sync)
    0:begin
   place_text(x,y,6'd36,10'd316,10'd318,10'd56,1'b0,24'ha2afc0);
    end
    1:begin
   place_text(x,y,6'd37,10'd316,10'd318,10'd56,1'b0,24'ha2afc0);
    end
    3:begin
   place_text(x,y,6'd39,10'd316,10'd318,10'd56,1'b0,24'ha2afc0);
    end
   endcase
   end
   if(!photo_ready)begin
   place_text(x,y,6'd34,10'd118,10'd202,10'd96,1'b0,24'ha2afc0);
   end
   place_text(x,y,6'd42,10'd436,10'd118,10'd64,1'b0,24'hf2f5f9);
   place_text(x,y,6'd43,10'd436,10'd146,10'd64,1'b0,24'hf2f5f9);
   place_text(x,y,6'd3,10'd492,10'd286,10'd48,1'b0,24'hf2f5f9);
   place_text(x,y,6'd13,10'd436,10'd344,10'd64,1'b0,24'ha2afc0);
   place_text(x,y,6'd8,10'd28,10'd432,10'd88,1'b0,24'ha2afc0);
   place_text(x,y,6'd28,10'd540,10'd432,10'd72,1'b0,24'h75d3c4);

   end
   2:begin end // Arcade renderer owns this page.
   3:begin
   place_text(x,y,6'd4,10'd28,10'd24,10'd64,1'b1,24'hf2f5f9);
   place_text(x,y,6'd7,10'd116,10'd40,10'd80,1'b0,24'ha2afc0);
   place_text(x,y,6'd16,10'd48,10'd130,10'd64,1'b0,24'hf2f5f9);
   place_text(x,y,6'd17,10'd48,10'd202,10'd32,1'b0,24'hf2f5f9);
   place_text(x,y,6'd18,10'd48,10'd274,10'd64,1'b0,24'hf2f5f9);
   place_text(x,y,PHOTO_CLEAN?6'd54:TRANSITIONS?6'd50:6'd19,10'd48,10'd346,10'd64,1'b0,24'hf2f5f9);
   case(brightness)
    0:begin
   place_text(x,y,6'd20,10'd560,10'd130,10'd24,1'b0,24'h75d3c4);
    end
    1:begin
   place_text(x,y,6'd21,10'd560,10'd130,10'd24,1'b0,24'h75d3c4);
    end
    2:begin
   place_text(x,y,6'd22,10'd560,10'd130,10'd24,1'b0,24'h75d3c4);
    end
    3:begin
   place_text(x,y,6'd23,10'd552,10'd130,10'd32,1'b0,24'h75d3c4);
    end
   endcase
   case(sound_enable?volume:3'd0)
    0:begin
   place_text(x,y,6'd41,10'd568,10'd202,10'd16,1'b0,24'h75d3c4);
    end
    1:begin
   place_text(x,y,6'd20,10'd560,10'd202,10'd24,1'b0,24'h75d3c4);
    end
    2:begin
   place_text(x,y,6'd21,10'd560,10'd202,10'd24,1'b0,24'h75d3c4);
    end
    3:begin
   place_text(x,y,6'd22,10'd560,10'd202,10'd24,1'b0,24'h75d3c4);
    end
    4:begin
   place_text(x,y,6'd23,10'd552,10'd202,10'd32,1'b0,24'h75d3c4);
    end
    default:begin end
   endcase
   if(period_long)begin
   place_text(x,y,6'd27,10'd552,10'd274,10'd32,1'b0,24'h75d3c4);
   end else begin
   place_text(x,y,6'd26,10'd560,10'd274,10'd24,1'b0,24'h75d3c4);
   end
   if(PHOTO_CLEAN)begin end
   else if(TRANSITIONS)begin
    case(image_index_sync)
     1:place_text(x,y,6'd52,10'd552,10'd346,10'd32,1'b0,24'h75d3c4);
     2:place_text(x,y,6'd53,10'd536,10'd346,10'd48,1'b0,24'h75d3c4);
     default:place_text(x,y,6'd51,10'd520,10'd346,10'd64,1'b0,24'h75d3c4);
    endcase
   end else place_text(x,y,6'd40,10'd512,10'd346,10'd72,1'b0,24'ha2afc0);
   place_text(x,y,6'd29,10'd28,10'd422,10'd184,1'b0,24'ha2afc0);
   place_text(x,y,6'd30,10'd28,10'd452,10'd144,1'b0,24'ha2afc0);

   end
   default:begin end
  endcase
  if(list_open)begin
   text_area=0;font_big=0;
   place_text(x,y,list_type?6'd45:6'd44,10'd64,10'd62,10'd128,1'b0,24'hf2f5f9);
   place_text(x,y,6'd8,10'd64,10'd420,10'd88,1'b0,24'ha2afc0);
   place_text(x,y,6'd40,10'd264,10'd420,10'd72,1'b0,24'h75d3c4);
   place_text(x,y,6'd9,10'd416,10'd420,10'd112,1'b0,24'ha2afc0);
   if(list_count>4)place_text(x,y,list_cursor[2]?6'd49:6'd48,10'd512,10'd62,10'd40,1'b0,24'h75d3c4);
   if(!list_ready || list_count==0)begin
    place_text(x,y,list_ready?6'd47:6'd46,10'd264,10'd226,10'd96,1'b0,24'ha2afc0);
   end else if(y>=128 && y<384 && list_y[5:0]>=24 && list_y[5:0]<40 && {1'b0,list_index}<list_count)begin
    if(x>=144 && (title_kind!=0 ? x<272 : x<336))begin
     text_area=1;origin_x=144;origin_y=128+{list_y[7:6],6'd24};file_text=1;
     text_color=list_index==list_cursor?24'hf2f5f9:24'ha2afc0;
     if(title_kind==0 && x>=272)text_color=24'h8195a9;
    end else if(x>=96 && x<104)begin
     text_area=1;origin_x=96;origin_y=128+{list_y[7:6],6'd24};number_text=1;text_color=24'h75d3c4;
    end
   end
  end
 end
 reg [5:0] line_q;reg [9:0] dx_q,dy_q;reg large_q;
 reg char_valid_q;
 initial $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/menu_chars.hex",char_rom);
 wire [14:0] span=text_span(line_id);
 wire [5:0] static_column=(font_big && line_id==4)?{1'b0,dx[8:4]}:dx[8:3];
 wire prefetch_title=LIBRARY && list_open && x>=120 && x<144 && y>=128 && y<384;
 wire [8:0] char_addr=prefetch_title?{2'b11,list_type,list_index,3'd0}:(LIBRARY && file_text)?{2'b11,list_type,list_index,name_dx[6:4]}:span[14:6]+static_column;
 always @(posedge clk)begin char_q<=char_rom[char_addr];char_valid_q<=static_column<span[5:0];end
 wire [7:0] filename_char=filename_column_q<8?char_q:
   filename_column_q==8?8'h2e:filename_column_q==9?(filename_type_q?8'h53:8'h57):
   filename_column_q==10?8'h41:8'h56;
 wire [4:0] photo_ordinal=count_sync==0?5'd0:image_index_sync+1'b1;
 wire [4:0] photo_value=dx_q[5]?count_sync:photo_ordinal;
 wire [3:0] photo_tens=photo_value>=20?2:photo_value>=10?1:0;
 wire [3:0] photo_units=photo_value>=20?photo_value-20:photo_value>=10?photo_value-10:photo_value;
 wire photo_digit=MAX_IMAGES>4 && line_q==36 && (dx_q[8:3]==0 || dx_q[8:3]==1 || dx_q[8:3]==5 || dx_q[8:3]==6);
 wire [7:0] photo_char=8'd48+((dx_q[8:3]==0 || dx_q[8:3]==5)?photo_tens:photo_units);
 wire [7:0] small_glyph=photo_digit?library_glyph(photo_char):file_q?library_glyph(filename_char):number_q?library_glyph(8'd49+{5'd0,index_q}):(char_valid_q?char_q:8'd0);
 wire scaled_title=1'b0;
 wire [6:0] glyph_id=(large_q && !scaled_title)?large_info(line_q,dx_q[8:5],{dy_q[4],dx_q[4]}):small_glyph[7:1];
 wire [3:0] glyph_column=scaled_title?{small_glyph[0],dx_q[3:1]}:large_q?dx_q[3:0]:(file_q && title_kind_q==0)?{small_glyph[0],(dx_q[2:0]-3'd4)}:{small_glyph[0],dx_q[2:0]};
 wire [10:0] font_address={glyph_id,scaled_title?dy_q[4:1]:dy_q[3:0]};
 reg [31:0] font_q;reg [3:0] column_q;reg area_q;reg [23:0] ink_q;reg [9:0] xq,yq;
 reg [11:0] dictionary_index;reg [1:0] font_transform;
 always @(posedge clk)begin dictionary_index<=font_index[font_address];font_q<=font_dictionary[dictionary_index[9:0]];font_transform<=dictionary_index[11:10];end
 always @(posedge clk or posedge rst)begin
  if(rst)begin line_q<=0;dx_q<=0;dy_q<=0;large_q<=0;area_q<=0;ink_q<=0;xq<=0;yq<=0;list_q<=0;end
  else begin line_q<=line_id;dx_q<=dx;dy_q<=dy;large_q<=font_big;area_q<=text_area;ink_q<=text_color;xq<=x;yq<=y;list_q<=list_open;end
 end
 // Six-pixel stepped corners, constant comparisons only; no multipliers.
 function rounded;
  input [9:0] px,py,left,top,right,bottom;
  begin
   rounded=px>=left && px<right && py>=top && py<bottom &&
    !(((px<left+10'd1 || px>=right-10'd1)&&(py<top+10'd6 || py>=bottom-10'd6)) ||
      ((px<left+10'd2 || px>=right-10'd2)&&(py<top+10'd4 || py>=bottom-10'd4)) ||
      ((px<left+10'd4 || px>=right-10'd4)&&(py<top+10'd2 || py>=bottom-10'd2)) ||
      ((px<left+10'd6 || px>=right-10'd6)&&(py<top+10'd1 || py>=bottom-10'd1)));
  end
 endfunction
 function [7:0] mix_channel;input [7:0] bg,fg;input [1:0] a;reg [9:0] sum;begin
  case(a)
   0:mix_channel=bg;
   1:begin sum={2'b0,bg}+{1'b0,bg,1'b0}+{2'b0,fg};mix_channel=sum[9:2];end
   2:begin sum={2'b0,fg}+{1'b0,fg,1'b0}+{2'b0,bg};mix_channel=sum[9:2];end
   3:mix_channel=fg;
  endcase
 end endfunction
 reg [3:0] column_delay;
 // One bounded 512x16 ROM: both complete Chinese labels in one BRAM9K.
 // Match the existing character/dictionary pipeline; no extra video latency.
 reg [15:0] title_rom[0:511];reg [15:0] title_pixels_q,title_pixels_qq;
 reg title_active_q,title_active_qq;reg file_visible_q,file_visible_qq;reg [2:0] title_row_q,title_row_qq;
 initial $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/library_titles.hex",title_rom);
 always @(posedge clk)begin
  file_visible_q<=!file_q || title_kind_q!=0 || (dx_q[3:0]>=4 && dx_q[3:0]<12);
  file_visible_qq<=file_visible_q;
  title_pixels_q<=title_rom[{title_kind_q==2,dx_q[6:0],dy_q[3]}];
  title_pixels_qq<=title_pixels_q;
  title_active_q<=LIBRARY && file_q && title_kind_q!=0;
  title_active_qq<=title_active_q;
  title_row_q<=dy_q[2:0];title_row_qq<=title_row_q;
 end
 wire [1:0] raw_coverage=font_q[31-(column_delay^{4{font_transform[1]}})*2-:2];
 wire [1:0] font_coverage=font_transform[0]?{raw_coverage[0],raw_coverage[1]}:raw_coverage;
 wire [1:0] coverage=!file_visible_qq?2'd0:title_active_qq?title_pixels_qq[15-title_row_qq*2-:2]:font_coverage;
 reg [23:0] base;reg [4:0] style;reg [9:0] row_top;reg [1:0] row;reg is_row;
 integer k;reg brick;
 always @*begin
  style=0;
  row_top=0;row=0;is_row=0;brick=0;
  if(xq>=28 && xq<612 && yq==80)style=5'd2;
  if(xq>=28 && xq<612 && yq==412)style=5'd2;
  if(page==0)begin
   if(rounded(xq,yq,532,28,612,64))style=home_selected==2?5'd3:5'd4;
   // Compact sliders icon at the settings shortcut.
   if(xq>=542 && xq<554 && (yq==38 || yq==45 || yq==52))style=home_selected==2?5'd5:5'd6;
   if((xq>=545 && xq<548 && yq>=36 && yq<41)||(xq>=550 && xq<553 && yq>=43 && yq<48)||(xq>=543 && xq<546 && yq>=50 && yq<55))style=home_selected==2?5'd7:5'd8;
   if(rounded(xq,yq,30,104,404,394))style=5'd9;
   if(rounded(xq,yq,28,100,400,388))style=home_selected==0?5'd3:5'd10;
   if(rounded(xq,yq,29,101,399,387))style=home_selected==0?5'd18:5'd11;
   if(rounded(xq,yq,36,108,392,300))begin
    if(photo_ready)begin
     style=1;
    end else begin
     style=5'd12;
     if(xq>=150 && xq<182 && yq>=160 && yq<184)style=5'd13;
     if(xq>=154 && xq<178 && yq>=164 && yq<180)style=5'd14;
    end
   end
   if(home_selected==0 && rounded(xq,yq,358,344,384,370))style=5'd15;
   if(xq>=369 && xq<375 && yq>=352 && yq<362 && ((xq-10'd369)==(yq-10'd352) || (xq-10'd369)==(10'd361-yq)))style=home_selected==0?5'd3:5'd6;
   if(xq>=424 && xq<616 && yq>=108 && yq<250)style=5'd9;
   if(rounded(xq,yq,420,100,612,244))style=home_selected==3?5'd3:5'd10;
   if(rounded(xq,yq,421,101,611,243))style=home_selected==3?5'd18:5'd16;
   if(xq>=430 && xq<602 && yq==102)style=home_selected==3?5'd23:5'd17;
   if(xq>=430 && xq<602 && yq==241)style=5'd24;
   // Calm poster illustration and a separate clear transport action.
   if(rounded(xq,yq,436,176,540,228))style=5'd17;
   if(rounded(xq,yq,439,179,537,225))begin
    style=5'd12;
    if(yq>=199 && xq-439<=(yq-199)*2)style=5'd22;
    if(yq>=194 && 537-xq<=(yq-194)*2)style=5'd5;
    if(yq>=217)style=5'd15;
    if(xq>=515 && xq<521 && yq>=185 && yq<191)style=5'd21;
   end
   if(rounded(xq,yq,558,182,596,224))style=home_selected==3?5'd3:5'd17;
   if(xq>=571 && xq<584 && yq>=193 && yq<213 && xq-571<=(yq<203?yq-193:212-yq))style=home_selected==3?5'd7:5'd3;
   if(xq>=424 && xq<616 && yq>=272 && yq<394)style=5'd9;
   if(rounded(xq,yq,420,264,612,388))style=home_selected==1?5'd3:5'd10;
   if(rounded(xq,yq,421,265,611,387))style=home_selected==1?5'd18:5'd16;
   if(xq>=430 && xq<602 && yq==266)style=home_selected==1?5'd23:5'd17;
   if(xq>=430 && xq<602 && yq==385)style=5'd24;
   // A small controller, keeping the upcoming feature visually secondary.
   if(rounded(xq,yq,436,282,478,310))style=5'd19;
   if((xq>=444 && xq<448 && yq>=288 && yq<304)||(xq>=438 && xq<454 && yq>=294 && yq<298))style=5'd20;
   if(xq>=465 && xq<470 && yq>=288 && yq<293)style=5'd3;
   if(xq>=470 && xq<475 && yq>=298 && yq<303)style=5'd21;
  end else if(page==3)begin
   if(yq>=110 && yq<166)begin row=0;row_top=110;is_row=1;end
   else if(yq>=182 && yq<238)begin row=1;row_top=182;is_row=1;end
   else if(yq>=254 && yq<310)begin row=2;row_top=254;is_row=1;end
   else if(yq>=326 && yq<382)begin row=3;row_top=326;is_row=1;end
   if(is_row && rounded(xq,yq,28,row_top,612,row_top+56))style=settings_selected==row?5'd3:5'd10;
   if(is_row && rounded(xq,yq,29,row_top+1,611,row_top+55))style=settings_selected==row?5'd18:5'd16;
   if(is_row && xq>=38 && xq<602 && yq==row_top+2)style=settings_selected==row?5'd23:5'd17;
   if(is_row && settings_selected==row && xq>=28 && xq<32 && yq>=row_top+12 && yq<row_top+44)style=5'd3;
   if(is_row && row<3 && rounded(xq,yq,536,row_top+12,596,row_top+42))style=5'd15;
   if(is_row && row<2 && yq>=row_top+44 && yq<row_top+47)begin
    for(k=0;k<4;k=k+1)begin
     if(xq>=48+k*116 && xq<158+k*116)
      style=((row==0 && k<=brightness) || (row==1 && sound_enable && k<volume))?5'd3:5'd17;
    end
   end
   if(PHOTO_CLEAN && rounded(xq,yq,536,346,584,366))style=clean_photo?5'd15:5'd13;
   if(PHOTO_CLEAN && rounded(xq,yq,clean_photo?10'd566:10'd538,348,clean_photo?10'd582:10'd554,364))style=clean_photo?5'd3:5'd14;
  end
  if(list_q)begin
   style=0;
   if(rounded(xq,yq,40,40,600,400))style=5'd11;
   if(xq>=64 && xq<576 && yq==100)style=5'd2;
   if(list_ready && list_count!=0 && yq>=128 && yq<384 && {1'b0,list_cursor[2],yq[7:6]-2'd2}<list_count)begin
    row_top={yq[9:6],6'd0}+10'd8;
    if(rounded(xq,yq,64,row_top,576,row_top+48))style=5'd10;
    if(rounded(xq,yq,65,row_top+1,575,row_top+47))
     style=(yq[7:6]-2'd2)==list_cursor[1:0]?5'd18:5'd16;
    if(xq>=74 && xq<566 && yq==row_top+2)style=(yq[7:6]-2'd2)==list_cursor[1:0]?5'd23:5'd17;
    if(rounded(xq,yq,84,row_top+8,116,row_top+40))
     style=(yq[7:6]-2'd2)==list_cursor[1:0]?5'd15:5'd17;
    if((yq[7:6]-2'd2)==list_cursor[1:0])begin
     if(xq>=64 && xq<68 && yq>=row_top+12 && yq<row_top+36)style=5'd3;
     if(rounded(xq,yq,536,row_top+10,564,row_top+38))style=5'd15;
     if(xq>=547 && xq<554 && yq>=row_top+18 && yq<row_top+30 &&
       ((xq-10'd547)==(yq-row_top-10'd18) || (xq-10'd547)==(row_top+10'd29-yq)))style=5'd3;
    end
   end
  end
 end
 always @*begin
  case(style)
   0:base={8'd10+{5'd0,yq[8:6]},8'd18+{5'd0,yq[8:6]},8'd30+{4'd0,yq[8:5]}};
   1:base=rgb_in;
   5'd2:base=24'h263344;
   5'd3:base=24'h75d3c4;
   5'd4:base=24'h1b2a3b;
   5'd5:base=24'h315b60;
   5'd6:base=24'ha2afc0;
   5'd7:base=24'h102c30;
   5'd8:base=24'hf2f5f9;
   5'd9:base=24'h070c13;
   5'd10:base=24'h29384b;
   5'd11:base=24'h172534;
   5'd12:base=24'h1b3044;
   5'd13:base=24'h334859;
   5'd14:base=24'h8195a9;
   5'd15:base=24'h284c50;
   5'd16:base={{5'b00100,~yq[8:6]},{4'b0011,~yq[8:6],1'b0},{4'b0100,~yq[8:6],1'b0}};
   5'd17:base=24'h334a60;
   5'd18:base={{4'b0010,~yq[8:5]},{3'b010,~yq[8:5],1'b0},{3'b011,~yq[8:5],1'b0}};
   5'd19:base=24'h3b526a;
   5'd20:base=24'hd0dbe5;
   5'd21:base=24'hefc68f;
   5'd22:base=24'h8eb8ca;
   5'd23:base=24'h739caa;
   5'd24:base=24'h12232e;
   default:base=0;
  endcase
 end
 reg [23:0] base_q,ink_qq,passthrough_q;reg area_qq;reg [1:0] page_qq;reg list_qq,list_qqq;
 always @(posedge clk or posedge rst)begin
  if(rst)begin base_q<=0;ink_qq<=0;passthrough_q<=0;area_qq<=0;column_q<=0;page_qq<=0;list_qq<=0;end
  else begin base_q<=base;ink_qq<=ink_q;passthrough_q<=rgb_in;area_qq<=area_q;column_q<=glyph_column;page_qq<=page;list_qq<=list_q;end
 end
 reg [23:0] base_qq,ink_qqq,passthrough_qq;reg area_qqq;reg [1:0] page_qqq;
 always @(posedge clk or posedge rst)begin
  if(rst)begin base_qq<=0;ink_qqq<=0;passthrough_qq<=0;area_qqq<=0;page_qqq<=0;column_delay<=0;list_qqq<=0;end
  else begin base_qq<=base_q;ink_qqq<=ink_qq;passthrough_qq<=passthrough_q;area_qqq<=area_qq;page_qqq<=page_qq;column_delay<=column_q;list_qqq<=list_qq;end
 end
 always @*begin
  rgb_out=base_qq;
  if(area_qqq)rgb_out={mix_channel(base_qq[23:16],ink_qqq[23:16],coverage),mix_channel(base_qq[15:8],ink_qqq[15:8],coverage),mix_channel(base_qq[7:0],ink_qqq[7:0],coverage)};
  if(page_qqq==1 && !list_qqq)rgb_out=passthrough_qq;
 end
endmodule

