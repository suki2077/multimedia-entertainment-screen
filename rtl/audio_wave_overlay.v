// Actual PCM envelope, 32 columns with 24-sample peaks (16 ms per capture).
// One 64x12 dual-bank RAM stores raw level, falling peak and display height.
// A 96-clock blanking update smooths release without a second RAM or any DSP.
// This visualizes temporal amplitude; it is not an FFT frequency spectrum.
module audio_wave_overlay(input wire clk,rst,vs,audio_valid,input wire [23:0] pcm,
 input wire [9:0] x,y,input wire [23:0] rgb_in,output wire [23:0] rgb_out);
 reg [11:0] samples[0:63];
 reg display_bank,write_bank,display_valid,display_active,vs_q,capture_done,updating;
 reg [4:0] capture_col,sample_count,update_col;
 reg [1:0] update_phase,fall_phase;
 reg [3:0] capture_peak,raw_saved;
 reg update_active;
 reg [11:0] sample_q;
 reg [9:0] xq,yq;
 wire frame_tick=vs_q && !vs;
 wire [7:0] magnitude=pcm[23]?(~pcm[23:16]+8'd1):pcm[23:16];
 wire [4:0] magnitude_step=magnitude[7:3];
 wire [3:0] instant=(magnitude_step==0)?4'd0:
     (magnitude_step<10)?magnitude_step[3:0]+4'd1:
     (magnitude_step>12)?4'd12:magnitude_step[3:0];
 wire [3:0] slot_peak=instant>capture_peak?instant:capture_peak;
 wire capture=!rst && audio_valid && !capture_done && !updating;
 wire capture_write=capture && sample_count==23;
 wire [9:0] dx=x-10'd64;
 wire [5:0] read_address=updating?
     {(update_phase==0?write_bank:display_bank),update_col}:{display_bank,dx[8:4]};
 wire [3:0] old_height=display_valid?sample_q[3:0]:4'd0;
 wire [3:0] old_peak=display_valid?sample_q[7:4]:4'd0;
 wire [3:0] released=old_height!=0?old_height-4'd1:4'd0;
 wire [3:0] next_height=raw_saved>released?raw_saved:released;
 wire [3:0] fallen=(old_peak!=0 && fall_phase==0)?old_peak-4'd1:old_peak;
 wire [3:0] next_peak=raw_saved>fallen?raw_saved:fallen;
 always @(posedge clk)begin
  sample_q<=samples[read_address];
  if(updating && update_phase==2)
   samples[{write_bank,update_col}]<={raw_saved,next_peak,next_height};
  else if(capture_write)samples[{write_bank,capture_col}]<={slot_peak,8'd0};
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   display_bank<=0;write_bank<=1;display_valid<=0;display_active<=0;vs_q<=1;
   capture_done<=0;updating<=0;capture_col<=0;sample_count<=0;capture_peak<=0;
   update_col<=0;update_phase<=0;fall_phase<=0;raw_saved<=0;update_active<=0;xq<=0;yq<=0;
  end else begin
   vs_q<=vs;xq<=x;yq<=y;
   if(frame_tick && capture_done && !updating)begin
    updating<=1;update_phase<=0;update_col<=0;update_active<=0;
   end else if(updating)begin
    case(update_phase)
     0:update_phase<=1;
     1:begin raw_saved<=sample_q[11:8];update_phase<=2;end
     2:begin
      update_active<=update_active || next_height!=0 || next_peak!=0;
      update_phase<=0;
      if(update_col==31)begin
       display_bank<=write_bank;write_bank<=display_bank;display_valid<=1;
       display_active<=update_active || next_height!=0 || next_peak!=0;
       updating<=0;capture_done<=0;capture_col<=0;sample_count<=0;capture_peak<=0;
       fall_phase<=fall_phase+1'b1;
      end else update_col<=update_col+1'b1;
     end
    endcase
   end else if(capture)begin
    if(sample_count==23)begin
     sample_count<=0;capture_peak<=0;
     if(capture_col==31)capture_done<=1;else capture_col<=capture_col+1'b1;
    end else begin sample_count<=sample_count+1'b1;capture_peak<=slot_peak;end
   end
  end
 end
 function [23:0] gradient;input [3:0] row;
 begin case(row)
  0:gradient=24'h28decf;1:gradient=24'h36d9dc;2:gradient=24'h48cdef;
  3:gradient=24'h66b9f1;4:gradient=24'h8c9cf4;5:gradient=24'hac91ed;
  6:gradient=24'hc891df;7:gradient=24'he2a0cc;8:gradient=24'hf0b1b3;
  9:gradient=24'hf8c492;10:gradient=24'hfedb83;default:gradient=24'hffe79b;
 endcase end endfunction
 function [23:0] tint;input [23:0] c;
 begin tint={(c[23:16]>>3)+8'd5,(c[15:8]>>3)+8'd12,(c[7:0]>>3)+8'd24};end endfunction
 wire [9:0] dxq=xq-10'd64,dy=10'd437-yq;
 wire panel=display_valid && display_active && xq>=64 && xq<576 && yq>=340 && yq<444 &&
     !((xq<68 || xq>=572) && (yq<344 || yq>=440));
 wire tile=dxq[3:0]<12 && yq>=342 && yq<438 && dy[2:0]!=0;
 wire lit=tile && dy[6:3]<sample_q[3:0];
 wire [9:0] peak_y=10'd437-{3'd0,sample_q[7:4],3'd0};
 wire cap=dxq[3:0]<12 && sample_q[7:4]!=0 && yq>=peak_y && yq<peak_y+2;
 wire [23:0] color=gradient(dy[6:3]);
 wire [23:0] highlight=color|24'h181818;
 wire edge_pixel=xq==64 || xq==575 || yq==340 || yq==443;
 assign rgb_out=!panel?rgb_in:
    edge_pixel?24'h28445c:
    cap?24'hffd8b2:
    lit?(dy[2:0]==7?highlight:color):
    tile?24'h102338:tint(rgb_in);
endmodule
