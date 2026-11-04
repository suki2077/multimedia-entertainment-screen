// Bundled state is stable before the three-stage toggle event is observed.
// Commit only in vertical blank; never show an intermediate multi-bit page.
module ui_state_cdc(input wire clk,rst,vs,source_toggle,input wire [6:0] source_state,
 output reg [2:0] page,output reg [1:0] home_selected,settings_selected);
 reg [2:0] event_pipe;reg [6:0] meta,data,pending;reg seen,have_pending,vs_q;
 wire event_new=event_pipe[2]!=seen;wire frame_tick=vs_q && !vs;
 always @(posedge clk or posedge rst)begin
  if(rst)begin event_pipe<=0;meta<=0;data<=0;pending<=0;seen<=0;have_pending<=0;vs_q<=1;
   page<=0;home_selected<=0;settings_selected<=0;end
  else begin
   event_pipe<={event_pipe[1:0],source_toggle};meta<=source_state;data<=meta;vs_q<=vs;
   if(event_new)begin seen<=event_pipe[2];pending<=data;have_pending<=1;end
   if(frame_tick && (have_pending || event_new))begin
    {page,home_selected,settings_selected}<=event_new?data:pending;have_pending<=0;
   end
  end
 end
endmodule
