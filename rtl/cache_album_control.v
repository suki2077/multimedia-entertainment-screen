// Foreground presentation has priority over quiet background warming of four tagged cache slots for up to twenty files.
// A cached presentation holds the BMP loader reset: it issues no SD request.
module cache_album_control #(
 parameter TICK_CYCLES=71429,HOLD_TICKS=5000,HOLD_TICKS_LONG=10000,MAX_IMAGES=4,SCAN=0,TAGGED=0,IMAGE_BITS=$clog2(MAX_IMAGES)
)(input wire clk,rst,init_done,next_press,prev_press,mode_press,period_long,
 input wire presentation_active,
 input wire swapped,load_failed,fatal_error,input wire [IMAGE_BITS-1:0] displayed,
 input wire [MAX_IMAGES-1:0] cache_valid,
 output reg [IMAGE_BITS-1:0] selected,output wire busy,started,loader_reset,
 output reg begin_load,auto_mode,all_failed,output reg prefetch,promote,input wire scan_done,input wire [4:0] scan_count,
 output wire scan_only,output wire [4:0] photo_count,
 input wire [4*IMAGE_BITS-1:0] cache_tags,input wire [3:0] cache_slots_valid);
 localparam WAIT_INIT=0,RESET_LOAD=1,WAIT_LOAD=2,IDLE=3,STOPPED=4,SCAN_RESET=5,SCAN_WAIT=6,SETTLE_CANDIDATE=7;
 reg [2:0] state;reg [5:0] reset_count;reg cached_job,forward;
 reg [IMAGE_BITS-1:0] failures;reg [MAX_IMAGES-1:0] skip_mask;reg [4:0] count;
 assign photo_count=count;assign scan_only=SCAN && (state==SCAN_RESET || state==SCAN_WAIT);
 reg [16:0] tick_count;reg [13:0] hold_count;
 reg period_meta,period_sync,period_used;reg dwell_expired,loader_reset_q;
 wire period_changed=period_sync!=period_used;
 always @(posedge clk or posedge rst)begin
  if(rst)dwell_expired<=0;
  else dwell_expired<=tick_count==TICK_CYCLES-1 && hold_count==(period_used?HOLD_TICKS_LONG-1:HOLD_TICKS-1);
 end
 wire auto_due=presentation_active && auto_mode && !mode_press && !period_changed && dwell_expired;
 function [IMAGE_BITS-1:0] step_image;input [IMAGE_BITS-1:0] n;input back;input [4:0] limit;begin
  if(back)step_image=n==0?limit-1'b1:n-1'b1;
  else step_image=n+1'b1>=limit?0:n+1'b1;
 end endfunction
 function cached;
 input [IMAGE_BITS-1:0] n;input [4*IMAGE_BITS-1:0] tags;input [3:0] valid;input [MAX_IMAGES-1:0] bitmap;
 begin
  if(TAGGED)cached=(valid[0] && n==tags[0+:IMAGE_BITS]) || (valid[1] && n==tags[IMAGE_BITS+:IMAGE_BITS]) ||
   (valid[2] && n==tags[2*IMAGE_BITS+:IMAGE_BITS]) || (valid[3] && n==tags[3*IMAGE_BITS+:IMAGE_BITS]);
  else cached=bitmap[n];
 end endfunction
 reg [IMAGE_BITS-1:0] next_image,prev_image;
 always @(posedge clk or posedge rst)begin
  if(rst)begin next_image<=0;prev_image<=0;end
  else begin next_image<=step_image(displayed,0,count);prev_image<=step_image(displayed,1,count);end
 end
 reg candidate_valid;reg [IMAGE_BITS-1:0] candidate;
 wire [IMAGE_BITS-1:0] p1=next_image,p2=step_image(next_image,0,count),
 p3=prev_image;
 always @*begin
   candidate_valid=1;
   if(!cached(p1,cache_tags,cache_slots_valid,cache_valid) && !skip_mask[p1])candidate=p1;
   else if(!cached(p2,cache_tags,cache_slots_valid,cache_valid) && !skip_mask[p2])candidate=p2;
   else if(!cached(p3,cache_tags,cache_slots_valid,cache_valid) && !skip_mask[p3])candidate=p3;
   else if(!cached(displayed,cache_tags,cache_slots_valid,cache_valid) && !skip_mask[displayed])candidate=displayed;
   else begin candidate=0;candidate_valid=0;end
 end
 // Break the four-way tagged-cache priority path before issuing a new job.
 // A settling cycle after a commit/failure lets next_image and this snapshot
 // both catch up, so a stale candidate cannot re-read a failed image.
 reg candidate_valid_q;reg [IMAGE_BITS-1:0] candidate_q;
 always @(posedge clk or posedge rst)begin
  if(rst)begin candidate_valid_q<=0;candidate_q<=0;end
  else begin candidate_valid_q<=candidate_valid;candidate_q<=candidate;end
 end
 assign busy=(state==WAIT_INIT || state==SCAN_RESET || state==SCAN_WAIT)||((state==RESET_LOAD || state==WAIT_LOAD)&&!prefetch);
 assign started=(state!=WAIT_INIT);
 assign loader_reset=loader_reset_q;
 always @(posedge clk or posedge rst)begin
  if(rst)loader_reset_q<=1;
  else loader_reset_q<=state==WAIT_INIT || state==IDLE || state==STOPPED || state==RESET_LOAD || state==SCAN_RESET || cached_job;
 end
 task launch;
   input [IMAGE_BITS-1:0] target;input background;
   begin selected<=target;prefetch<=background;cached_job<=0;
     reset_count<=63;begin_load<=1;state<=RESET_LOAD;end
 endtask
 task foreground;
   input [IMAGE_BITS-1:0] target;
   begin
     if(target==selected)begin prefetch<=0;promote<=1;end
     else launch(target,0);
   end
 endtask
 always @(posedge clk or posedge rst)begin
  if(rst)begin period_meta<=0;period_sync<=0;period_used<=0;end
  else begin period_meta<=period_long;period_sync<=period_meta;period_used<=period_sync;end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=WAIT_INIT;count<=MAX_IMAGES;selected<=0;reset_count<=0;cached_job<=0;forward<=1;
    failures<=0;skip_mask<=0;tick_count<=0;hold_count<=0;begin_load<=0;
    auto_mode<=0;all_failed<=0;prefetch<=0;promote<=0;end
  else begin
   begin_load<=0;promote<=0;
   if(mode_press && !fatal_error)auto_mode<=~auto_mode;
   // Dwell runs while prefetching; background I/O must not postpone auto playback.
   if(!presentation_active || busy || !auto_mode || mode_press || period_changed)begin tick_count<=0;hold_count<=0;end
   else if(tick_count==TICK_CYCLES-1)begin tick_count<=0;hold_count<=hold_count+1'b1;end
   else tick_count<=tick_count+1'b1;
   case(state)
    WAIT_INIT:if(init_done)begin
     if(SCAN)begin count<=0;reset_count<=63;state<=SCAN_RESET;end else launch(0,0);
    end
    SCAN_RESET:if(reset_count==0)state<=SCAN_WAIT;else reset_count<=reset_count-1'b1;
    SCAN_WAIT:begin
     if(scan_done)begin
      count<=scan_count;
      if(scan_count==0)begin all_failed<=1;state<=STOPPED;end else launch(0,0);
     end else if(load_failed)begin all_failed<=1;state<=STOPPED;end
    end
    RESET_LOAD:begin
      cached_job<=cached(selected,cache_tags,cache_slots_valid,cache_valid);
      if(prefetch && (next_press || prev_press || auto_due))begin
        forward<=!prev_press;failures<=0;all_failed<=0;
        foreground(prev_press?prev_image:next_image);
      end else if(reset_count==0)state<=WAIT_LOAD;
      else reset_count<=reset_count-1'b1;
    end
    WAIT_LOAD:begin
      if(prefetch)begin
        if(next_press || prev_press || auto_due)begin
          forward<=!prev_press;failures<=0;all_failed<=0;
          foreground(prev_press?prev_image:next_image);
        end else if(cached(selected,cache_tags,cache_slots_valid,cache_valid))begin state<=SETTLE_CANDIDATE;prefetch<=0;end
        else if(load_failed)begin skip_mask[selected]<=1;state<=SETTLE_CANDIDATE;prefetch<=0;end
      end else if(swapped)begin failures<=0;all_failed<=0;state<=SETTLE_CANDIDATE;end
      else if(load_failed && !cached_job)begin
        if(failures==count-1'b1)begin all_failed<=1;auto_mode<=0;state<=STOPPED;end
        else begin failures<=failures+1'b1;launch(step_image(selected,!forward,count),0);end
      end
    end
    IDLE,SETTLE_CANDIDATE:begin
      if(next_press || prev_press || auto_due)begin
        forward<=!prev_press;failures<=0;skip_mask<=0;
        launch(prev_press?prev_image:next_image,0);
      end else if(state==SETTLE_CANDIDATE)state<=IDLE;
      else if(candidate_valid_q)launch(candidate_q,1);
    end
    STOPPED:if(!fatal_error && (next_press || prev_press || mode_press))begin
      if(SCAN && count==0)begin reset_count<=63;state<=SCAN_RESET;end else begin
      failures<=0;all_failed<=0;skip_mask<=0;forward<=!prev_press;
      launch(next_press?next_image:prev_press?prev_image:selected,0);
    end
    end
    default:state<=STOPPED;
   endcase
   if(fatal_error)begin state<=STOPPED;auto_mode<=0;prefetch<=0;end
  end
 end
endmodule
