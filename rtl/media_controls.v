// Frame-latched settings. UI adjustments persist until that physical switch changes.
module media_controls #(parameter DEBOUNCE_CYCLES=200000,TRANSITIONS=0,PHOTO_CLEAN=0,VOICE=0)(
 input wire clk,rst,input wire [3:0] switches,input wire vs,video_mode,
 input wire setting_toggle,input wire [1:0] setting_command,
 output reg [1:0] brightness,output reg sound_enable,period_long,output reg [2:0] volume,output reg [1:0] transition_mode,output reg clean_photo,
 input wire voice_valid,input wire [3:0] voice_command);
 reg voice_volume_pending,voice_brightness_pending;
 reg [2:0] voice_volume_target;
 reg [1:0] voice_brightness_target;
 wire voice_volume_event=VOICE && voice_valid && (voice_command==11 || voice_command==12);
 wire voice_brightness_event=VOICE && voice_valid && (voice_command==13 || voice_command==14);
 wire [2:0] voice_volume_base=voice_volume_pending?voice_volume_target:volume;
 wire [1:0] voice_brightness_base=voice_brightness_pending?voice_brightness_target:brightness;
 wire [2:0] voice_volume_next=!voice_volume_event?voice_volume_base:
  voice_command==11?(voice_volume_base<4?voice_volume_base+3'd1:3'd4):
  (voice_volume_base!=0?voice_volume_base-3'd1:3'd0);
 wire [1:0] voice_brightness_next=!voice_brightness_event?voice_brightness_base:
  voice_command==13?(voice_brightness_base<3?voice_brightness_base+2'd1:2'd3):
  (voice_brightness_base!=0?voice_brightness_base-2'd1:2'd0);
 reg [3:0] meta,sync,candidate,stable,last_switches;reg [17:0] count;reg vs_q;
 reg [2:0] event_pipe;reg [1:0] command_meta,command_sync;reg event_seen;
 wire config_event=event_pipe[2]!=event_seen;
 reg pending_clean;
 wire clean_flip=pending_clean^(PHOTO_CLEAN && config_event && command_sync==3 && !video_mode);
 reg [2:0] pending_up;reg [1:0] pending_fx;
 wire [1:0] fx_steps=(TRANSITIONS && config_event && command_sync==3 && !video_mode)?(pending_fx==2 ? 2'd0 : pending_fx+2'd1):pending_fx;
 wire [2:0] fx_sum={1'b0,transition_mode}+{1'b0,fx_steps};
 reg [1:0] pending_brightness;reg [2:0] pending_volume;reg pending_period;
 wire [1:0] steps=pending_brightness+((config_event && command_sync==0)?2'd1:2'd0);
 wire [2:0] volume_steps=(config_event && command_sync==1)?((pending_volume==4)?3'd0:pending_volume+3'd1):pending_volume;
 wire [3:0] volume_sum={1'b0,volume}+4'd5-{1'b0,volume_steps};
 wire [2:0] up_steps=pending_up+((config_event && command_sync==3 && video_mode)?3'd1:3'd0);
 wire signed [5:0] volume_target=$signed({3'b0,volume})+$signed({3'b0,up_steps})-$signed({3'b0,volume_steps});
 wire period_flip=pending_period^(config_event && command_sync==2);
 always @(posedge clk or posedge rst)begin
  if(rst)begin voice_volume_pending<=0;voice_brightness_pending<=0;voice_volume_target<=4;voice_brightness_target<=3;
   meta<=7;sync<=7;candidate<=7;stable<=7;last_switches<=7;count<=0;vs_q<=1;
   clean_photo<=0;pending_clean<=0;transition_mode<=0;pending_fx<=0;brightness<=3;sound_enable<=1;period_long<=0;volume<=4;event_pipe<=0;command_meta<=0;command_sync<=0;event_seen<=0;
   pending_brightness<=0;pending_volume<=0;pending_up<=0;pending_period<=0;end
  else begin
   voice_volume_pending<=voice_volume_pending || voice_volume_event;
   voice_brightness_pending<=voice_brightness_pending || voice_brightness_event;
   voice_volume_target<=voice_volume_next;voice_brightness_target<=voice_brightness_next;
   meta<=switches;sync<=meta;vs_q<=vs;
   event_pipe<={event_pipe[1:0],setting_toggle};command_meta<=setting_command;command_sync<=command_meta;
   if(config_event)event_seen<=event_pipe[2];
   pending_clean<=clean_flip;pending_fx<=fx_steps;pending_brightness<=steps;pending_volume<=volume_steps;pending_up<=up_steps;pending_period<=period_flip;
   if(sync!=candidate)begin candidate<=sync;count<=0;end
   else if(count<DEBOUNCE_CYCLES)count<=count+1'b1;else stable<=candidate;
   if(vs_q && !vs)begin
    voice_volume_pending<=0;voice_brightness_pending<=0;
    clean_photo<=PHOTO_CLEAN?(clean_photo^clean_flip):1'b0;pending_clean<=0;
    transition_mode<=fx_sum>=3 ? fx_sum-3'd3 : fx_sum[1:0];pending_fx<=0;
    brightness<=(stable[1:0]!=last_switches[1:0])?stable[1:0]:
     (VOICE && (voice_brightness_pending || voice_brightness_event))?voice_brightness_next:brightness+steps;
    sound_enable<=stable[2];
    if(VOICE && (voice_volume_pending || voice_volume_event))volume<=voice_volume_next;
    else if(video_mode)begin
      if(volume_target<0)volume<=0;else if(volume_target>4)volume<=4;else volume<=volume_target[2:0];
    end else volume<=volume_sum>=5?volume_sum-4'd5:volume_sum;
    period_long<=(stable[3]!=last_switches[3])?stable[3]:period_long^period_flip;
    last_switches<=stable;pending_brightness<=0;pending_volume<=0;pending_up<=0;pending_period<=0;
   end
  end
 end
endmodule
