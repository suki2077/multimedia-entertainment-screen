// Eight frame peaks from actual HDMI-bound PCM, not a free-running animation.
module home_audio_meter(input wire clk,rst,vs,audio_valid,input wire [23:0] pcm,
 input wire sound_enable,playing,output reg [31:0] levels);
 reg vs_q;reg[3:0] peak;
 wire[23:0] magnitude=pcm[23]?(~pcm+24'd1):pcm;
 wire[3:0] sample_level=(magnitude>=24'h780000)?4'd15:magnitude[22:19];
 wire[3:0] next_peak=(audio_valid && sample_level>peak)?sample_level:peak;
 always @(posedge clk or posedge rst)begin
  if(rst)begin vs_q<=1;peak<=0;levels<=0;end
  else begin
   vs_q<=vs;
   if(!sound_enable || !playing)begin peak<=0;levels<=0;end
   else if(vs_q && !vs)begin levels<={levels[27:0],next_peak};peak<=0;end
   else peak<=next_peak;
  end
 end
endmodule
