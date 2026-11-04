// Packet: 400 PCM words, 128 RGB565 palette words, 32400 four-index words,
// and 96 padding words. Palette RAM is synchronous; pixels enter the existing
// store as two RGB565 pairs. Backpressure holds each pair and source word stable.
module av_unpacker(input wire clk,rst,input wire valid,input wire [31:0] data,output wire ready,
 output wire video_valid,output wire [31:0] video_data,input wire video_ready,
 output wire audio_valid,output wire [15:0] audio_data,input wire audio_ready);
 reg [15:0] word_index;
 reg high_sample;
 reg [3:0] phase;
 reg [63:0] pixels;
 reg [15:0] palette[0:255];
 reg [15:0] palette_q;
 wire audio_part=word_index<400;
 wire palette_part=word_index>=400 && word_index<528;
 wire video_part=word_index>=528 && word_index<32928;
 wire [7:0] lookup_index=(phase<2)?data[7:0]:(phase<4)?data[15:8]:(phase<6)?data[23:16]:data[31:24];
 wire [6:0] palette_word=word_index-16'd400;
 always @(posedge clk)begin
  if(valid && palette_part)palette[{palette_word,high_sample}]<=high_sample?data[31:16]:data[15:0];
  palette_q<=palette[lookup_index];
 end
 assign audio_valid=valid && audio_part;
 assign audio_data=high_sample?data[31:16]:data[15:0];
 assign video_valid=valid && video_part && phase>=8;
 assign video_data=phase==8?pixels[31:0]:pixels[63:32];
 assign ready=audio_part?(audio_ready && high_sample):palette_part?high_sample:video_part?(phase==9 && video_ready):1'b1;
 always @(posedge clk or posedge rst)begin
  if(rst)begin word_index<=0;high_sample<=0;phase<=0;pixels<=0;end
  else begin
   if((audio_valid && audio_ready) || (valid && palette_part))high_sample<=~high_sample;
   if(valid && video_part)begin
    if(phase<8)begin
     if(phase[0])pixels[phase[3:1]*16+:16]<=palette_q;
     phase<=phase+1'b1;
    end else if(video_ready)begin
     if(phase==9)phase<=0;else phase<=9;
    end
   end
   if(valid && ready)begin
    if(word_index==33023)word_index<=0;else word_index<=word_index+1'b1;
   end
  end
 end
endmodule
