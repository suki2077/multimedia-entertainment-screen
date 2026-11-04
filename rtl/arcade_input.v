// One shared 1 ms sampler, three stable samples per direction.
// KEY4's short-release event arrives from the existing long/short key decoder.
module arcade_input #(parameter SAMPLE_CYCLES=25000)(
 input wire clk,rst,left_n,right_n,confirm_toggle,
 output reg left_held,right_held,left_click,right_click,confirm);
 reg [14:0] divider;reg [1:0] key_meta,key_sync;
 reg [2:0] left_history,right_history,event_pipe;reg event_seen;
 always @(posedge clk or posedge rst)begin
  if(rst)begin divider<=0;key_meta<=3;key_sync<=3;left_history<=7;right_history<=7;
   left_held<=0;right_held<=0;left_click<=0;right_click<=0;confirm<=0;event_pipe<=0;event_seen<=0;end
  else begin
   key_meta<={right_n,left_n};key_sync<=key_meta;
   event_pipe<={event_pipe[1:0],confirm_toggle};confirm<=event_pipe[2]!=event_seen;event_seen<=event_pipe[2];
   left_click<=0;right_click<=0;
   if(divider==SAMPLE_CYCLES-1)begin
    divider<=0;left_history<={left_history[1:0],key_sync[0]};right_history<={right_history[1:0],key_sync[1]};
    if(left_history==0 && !left_held)begin left_held<=1;left_click<=1;end
    if(left_history==7)left_held<=0;
    if(right_history==0 && !right_held)begin right_held<=1;right_click<=1;end
    if(right_history==7)right_held<=0;
   end else divider<=divider+1'b1;
  end
 end
endmodule
