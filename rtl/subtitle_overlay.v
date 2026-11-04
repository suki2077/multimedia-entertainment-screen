// 2048 columns x 24 pixels x two banks. Entire protocol and video live at pclk.
// Host renders Unicode glyphs; no font library or TF write is needed on FPGA.
module subtitle_overlay #(parameter GAP_TIMEOUT=12500000,REMOTE=0)(input wire clk,rst,vs,
 input wire rx_valid,rx_error,input wire [7:0] rx_data,
 output wire tx_valid,output reg [7:0] tx_data,input wire tx_ready,
 output reg remote_valid,output reg [3:0] remote_command,
 input wire [9:0] x,y,input wire [23:0] rgb_in,output reg [23:0] rgb_out);
 reg [23:0] columns[0:4095];
 reg [23:0] column_q;reg active_bank,active_valid,show_text,pending;
 reg [11:0] active_width,pending_width;reg [2:0] speed,pending_speed;
 reg pending_show;reg [23:0] color,pending_color;
 reg [12:0] scroll_pos;reg vs_q;
 wire frame_tick=vs_q && !vs;
 reg [9:0] xq,yq;reg [4:0] row_q;reg in_text_q;
 wire [12:0] cycle_width={1'b0,active_width}+13'd608;
 wire [12:0] extended_column=scroll_pos+{3'b0,x}-13'd16;
 wire [12:0] read_column=(extended_column>=cycle_width)?extended_column-cycle_width:extended_column;
 localparam SYNC0=0,SYNC1=1,HEADER=2,PAYLOAD=3,CRC_H=4,CRC_L=5,WAIT_FRAME=6;
 reg [2:0] state;reg [3:0] header_index;reg [7:0] sequence_id;
 reg [15:0] crc,received_crc;reg [11:0] packet_width;
 reg remote_packet;
 reg [10:0] column_index;reg [1:0] payload_byte;reg [15:0] payload_word;
 reg [23:0] gap_count;
 wire write_column=rx_valid && !rx_error && state==PAYLOAD && payload_byte==2;
 // Built-in boot caption: multimedia game screen.
 // A registered ROM path restores it on every reset; UART still replaces it atomically.
 reg default_mode;reg [23:0] default_q;
 function [23:0] default_column;input [7:0] index;begin case(index)
  8'd6:default_column=24'h001000;
  8'd7:default_column=24'h101180;
  8'd8:default_column=24'h119180;
  8'd9:default_column=24'h1198c0;
  8'd10:default_column=24'h18c860;
  8'd11:default_column=24'h18c820;
  8'd12:default_column=24'h086db0;
  8'd13:default_column=24'h0c2738;
  8'd14:default_column=24'h0db63c;
  8'd15:default_column=24'h071a30;
  8'd16:default_column=24'h061b30;
  8'd17:default_column=24'h021d30;
  8'd18:default_column=24'h0311b0;
  8'd19:default_column=24'h0190b0;
  8'd20:default_column=24'h0090f0;
  8'd21:default_column=24'h00d070;
  8'd22:default_column=24'h007030;
  8'd23:default_column=24'h003000;
  8'd26:default_column=24'h1830c0;
  8'd27:default_column=24'h0c7fc0;
  8'd28:default_column=24'h06c7f8;
  8'd29:default_column=24'h03c0d8;
  8'd30:default_column=24'h01f8c0;
  8'd31:default_column=24'h031fc0;
  8'd32:default_column=24'h184020;
  8'd33:default_column=24'h0c4030;
  8'd34:default_column=24'h064ff8;
  8'd35:default_column=24'h034ff8;
  8'd36:default_column=24'h01c930;
  8'd37:default_column=24'h00c930;
  8'd38:default_column=24'h1ff930;
  8'd39:default_column=24'h00c930;
  8'd40:default_column=24'h01c930;
  8'd41:default_column=24'h034db0;
  8'd42:default_column=24'h064ffc;
  8'd43:default_column=24'h0c4030;
  8'd44:default_column=24'h084030;
  8'd46:default_column=24'h001c00;
  8'd47:default_column=24'h000600;
  8'd48:default_column=24'h1fffc0;
  8'd49:default_column=24'h1ffff0;
  8'd50:default_column=24'h010018;
  8'd51:default_column=24'h0380c0;
  8'd52:default_column=24'h00c0c0;
  8'd53:default_column=24'h0070c0;
  8'd54:default_column=24'h013cc0;
  8'd55:default_column=24'h010fc0;
  8'd56:default_column=24'h0101c0;
  8'd57:default_column=24'h1ffffc;
  8'd58:default_column=24'h0383c8;
  8'd59:default_column=24'h0107c0;
  8'd60:default_column=24'h011cc0;
  8'd61:default_column=24'h0070c0;
  8'd62:default_column=24'h00c0c0;
  8'd63:default_column=24'h0180c0;
  8'd64:default_column=24'h010040;
  8'd66:default_column=24'h1800c0;
  8'd67:default_column=24'h187fc0;
  8'd68:default_column=24'h0e47f8;
  8'd69:default_column=24'h0380c8;
  8'd70:default_column=24'h01e0c0;
  8'd71:default_column=24'h037fc0;
  8'd72:default_column=24'h120380;
  8'd73:default_column=24'h18c800;
  8'd74:default_column=24'h18c9f8;
  8'd75:default_column=24'h0cc998;
  8'd76:default_column=24'h06c988;
  8'd77:default_column=24'h03c988;
  8'd78:default_column=24'h01f988;
  8'd79:default_column=24'h03c988;
  8'd80:default_column=24'h06c988;
  8'd81:default_column=24'h0cc988;
  8'd82:default_column=24'h18c9f8;
  8'd83:default_column=24'h18c9f0;
  8'd84:default_column=24'h108000;
  8'd86:default_column=24'h0c0000;
  8'd87:default_column=24'h0e0800;
  8'd88:default_column=24'h070ff0;
  8'd89:default_column=24'h0389f0;
  8'd90:default_column=24'h00c810;
  8'd91:default_column=24'h184810;
  8'd92:default_column=24'h180810;
  8'd93:default_column=24'h180810;
  8'd94:default_column=24'h180818;
  8'd95:default_column=24'h1fffd8;
  8'd96:default_column=24'h07ff98;
  8'd97:default_column=24'h000818;
  8'd98:default_column=24'h000818;
  8'd99:default_column=24'h004818;
  8'd100:default_column=24'h00c818;
  8'd101:default_column=24'h018808;
  8'd102:default_column=24'h030808;
  8'd103:default_column=24'h0e0800;
  8'd104:default_column=24'h0c0000;
  8'd106:default_column=24'h180000;
  8'd107:default_column=24'h0f0000;
  8'd108:default_column=24'h03fff8;
  8'd109:default_column=24'h0080d8;
  8'd110:default_column=24'h0088d8;
  8'd111:default_column=24'h1888d8;
  8'd112:default_column=24'h1c88d8;
  8'd113:default_column=24'h07d9d8;
  8'd114:default_column=24'h01ffd8;
  8'd115:default_column=24'h008cd8;
  8'd116:default_column=24'h0088d8;
  8'd117:default_column=24'h0088d8;
  8'd118:default_column=24'h008cd8;
  8'd119:default_column=24'h1ffed8;
  8'd120:default_column=24'h1ffbd8;
  8'd121:default_column=24'h0088d8;
  8'd122:default_column=24'h0088d8;
  8'd123:default_column=24'h0089f8;
  8'd124:default_column=24'h008000;
  default:default_column=24'd0;endcase end endfunction
 wire [23:0] caption_pixel=default_mode?default_q:column_q;
 // The RAM address and inside flag are computed from the same input pixel.
 always @(posedge clk)begin
   if(write_column)columns[{~active_bank,column_index}]<= {rx_data,payload_word};
   default_q<=default_column(read_column[7:0]);
   column_q<=columns[{active_bank,read_column[10:0]}];
 end
 reg reply_pending;reg [7:0] reply_code,reply_sequence;reg [2:0] reply_index;
 reg reply_active;
 function [15:0] crc_byte;
   input [15:0] current;input [7:0] b;integer j;reg [15:0] c;
   begin c=current^{b,8'd0};for(j=0;j<8;j=j+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc_byte=c;end
 endfunction
 wire [15:0] reply_crc=crc_byte(crc_byte(16'hffff,reply_sequence),reply_code);
 assign tx_valid=reply_active;
 always @*case(reply_index)
   0:tx_data=8'h5a;1:tx_data=8'ha5;2:tx_data=reply_sequence;3:tx_data=reply_code;
   4:tx_data=reply_crc[15:8];default:tx_data=reply_crc[7:0];endcase
 task reject;
   input [7:0] code;
   begin state<=SYNC0;reply_pending<=1;reply_code<=code;reply_sequence<=sequence_id;end
 endtask
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   remote_valid<=0;remote_command<=0;remote_packet<=0;
   default_mode<=1;active_bank<=0;active_valid<=1;show_text<=1;pending<=0;active_width<=12'd131;pending_width<=0;
   speed<=2;pending_speed<=2;pending_show<=0;color<=24'h58dfc0;pending_color<=24'hf3f6fa;
   scroll_pos<=0;vs_q<=1;xq<=0;yq<=0;row_q<=0;in_text_q<=0;
   state<=SYNC0;header_index<=0;sequence_id<=0;crc<=16'hffff;received_crc<=0;packet_width<=0;
   column_index<=0;payload_byte<=0;payload_word<=0;gap_count<=0;
   reply_pending<=0;reply_code<=0;reply_sequence<=0;reply_index<=0;reply_active<=0;
  end else begin
   remote_valid<=0;
   vs_q<=vs;xq<=x;yq<=y;row_q<=y-448;
   in_text_q<=x>=16 && x<624 && y>=448 && y<472 && read_column<active_width;
   if(frame_tick)begin
    if(pending)begin
     default_mode<=0;active_bank<=~active_bank;active_valid<=1;show_text<=pending_show;
     active_width<=pending_width;speed<=pending_speed;color<=pending_color;
     scroll_pos<=0;pending<=0;state<=SYNC0;
     reply_pending<=1;reply_sequence<=sequence_id;reply_code<=0;
    end else if(show_text && active_width!=0)begin
     if(scroll_pos+speed>=cycle_width)scroll_pos<=scroll_pos+speed-cycle_width;
     else scroll_pos<=scroll_pos+speed;
    end
   end
   if(reply_pending && !reply_active)begin reply_pending<=0;reply_active<=1;reply_index<=0;end
   else if(reply_active && tx_ready)begin
    if(reply_index==5)reply_active<=0;else reply_index<=reply_index+1'b1;
   end
   if(state==SYNC0 || state==SYNC1 || state==WAIT_FRAME)gap_count<=0;
   else if(rx_valid)gap_count<=0;
   else if(gap_count<GAP_TIMEOUT)gap_count<=gap_count+1'b1;
   else reject(8'd3);
   if(rx_error && state!=SYNC0 && state!=WAIT_FRAME)reject(8'd3);
   else if(rx_valid)begin
    case(state)
     SYNC0:if(rx_data==8'ha5 && !reply_active && !reply_pending)state<=SYNC1;
     SYNC1:if(rx_data==8'h5a)begin state<=HEADER;header_index<=0;crc<=16'hffff;packet_width<=0;end
       else if(rx_data!=8'ha5)state<=SYNC0;
     HEADER:begin
      crc<=crc_byte(crc,rx_data);header_index<=header_index+1'b1;
      case(header_index)
       0:begin remote_packet<=REMOTE && rx_data==2;if(rx_data!=1 && !(REMOTE && rx_data==2))reject(8'd2);end
       1:sequence_id<=rx_data;
       2:if(remote_packet)begin
        if(rx_data<1 || rx_data>15)reject(8'd2);
        else begin packet_width[3:0]<=rx_data[3:0];state<=CRC_H;end
       end else packet_width[7:0]<=rx_data;
       3:if(rx_data>8 || (rx_data==8 && packet_width[7:0]!=0))reject(8'd2);else packet_width[11:8]<=rx_data[3:0];
       4:if(rx_data<1 || rx_data>4)reject(8'd2);else pending_speed<=rx_data[2:0];
       5:if(rx_data[7:1]!=0)reject(8'd2);else pending_show<=rx_data[0];
       6:pending_color[23:16]<=rx_data;
       7:pending_color[15:8]<=rx_data;
       8:begin
        pending_color[7:0]<=rx_data;pending_width<=packet_width;column_index<=0;payload_byte<=0;
        state<=packet_width==0?CRC_H:PAYLOAD;
       end
      endcase
     end
     PAYLOAD:begin
      crc<=crc_byte(crc,rx_data);
      if(payload_byte==0)begin payload_word[7:0]<=rx_data;payload_byte<=1;end
      else if(payload_byte==1)begin payload_word[15:8]<=rx_data;payload_byte<=2;end
      else begin
       payload_byte<=0;
       if({1'b0,column_index}+12'd1==packet_width)state<=CRC_H;
       else column_index<=column_index+1'b1;
      end
     end
     CRC_H:begin received_crc[15:8]<=rx_data;state<=CRC_L;end
     CRC_L:if({received_crc[15:8],rx_data}==crc)begin
      if(remote_packet)begin remote_valid<=1;remote_command<=packet_width[3:0];state<=SYNC0;reply_pending<=1;reply_sequence<=sequence_id;reply_code<=0;end
      else begin pending<=1;state<=WAIT_FRAME;end
     end else reject(8'd1);
     default:begin end
    endcase
   end
  end
 end
 always @*begin
  rgb_out=rgb_in;
  if(active_valid && show_text && active_width!=0 && yq>=444 && yq<480)begin
   rgb_out={3'b0,rgb_in[23:19],3'b0,rgb_in[15:11],3'b0,rgb_in[7:3]}+24'h0b1523;
   if(yq==444 && xq>=16 && xq<624)rgb_out=24'h24374b;
   if(in_text_q && caption_pixel[row_q])rgb_out=color;
  end
 end
endmodule
