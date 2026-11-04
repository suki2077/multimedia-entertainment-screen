// Reuse 2048 x 32 RAM: each video word contains two sequential 24k mono
// samples, each repeated twice for 48k stereo HDMI output. Pop after four ticks.
module video_pcm_player(input wire clk,rst,enable,paused,
 input wire fifo_valid,input wire [31:0] fifo_data,input wire [12:0] fifo_level,
 output wire fifo_pop,output reg audio_valid,acr_valid,
 output reg [23:0] left_data,right_data,output reg frame_toggle,underrun,
 output reg playing,input wire [2:0] volume,input wire frame_available);
 reg [11:0] accumulator;
 reg [5:0] sample_count;
 reg [1:0] phase;
 reg started;
 reg [31:0] held;
 reg [10:0] frame_sample;
 wire tick=accumulator>=3119;
 wire frame_wait=frame_sample==799 && phase==3 && !frame_available;
 wire run=enable && !paused && started && !frame_wait;
 wire advance=run && (phase!=0 || fifo_valid);
 wire [15:0] sample=(phase==0)?fifo_data[15:0]:(phase==1)?held[15:0]:held[31:16];
 assign fifo_pop=tick && advance && phase==3;
 function [23:0] gain;input [15:0] s;input [2:0] v;reg signed [23:0] full;
 begin full=$signed({s,8'd0});case(v)
  4:gain=full;3:gain=full-(full>>>2);2:gain=full>>>1;1:gain=full>>>2;default:gain=0;
 endcase end endfunction
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   accumulator<=0;sample_count<=0;phase<=0;started<=0;held<=0;frame_sample<=0;
   audio_valid<=0;acr_valid<=0;left_data<=0;right_data<=0;frame_toggle<=0;underrun<=0;playing<=0;
  end else begin
   audio_valid<=0;acr_valid<=0;
   if(!started && enable && fifo_level>=400)started<=1;
   if(tick)begin
    accumulator<=accumulator-3119;audio_valid<=1;playing<=0;
    if(sample_count==47)begin sample_count<=0;acr_valid<=1;end else sample_count<=sample_count+1'b1;
    if(advance)begin
     if(phase==0)held<=fifo_data;
     left_data<=gain(sample,volume);right_data<=gain(sample,volume);phase<=phase+1'b1;playing<=1;
     if(phase[0])begin
      if(frame_sample==799)begin frame_sample<=0;frame_toggle<=~frame_toggle;end
      else frame_sample<=frame_sample+1'b1;
     end
    end else begin left_data<=0;right_data<=0;if(run && phase==0)underrun<=1;end
   end else accumulator<=accumulator+6;
  end
 end
endmodule
