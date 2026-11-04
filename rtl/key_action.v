// Confirm on release, HOME once after a long hold. A long hold never also confirms.
module key_action #(parameter DEBOUNCE=1428571,LONG_CYCLES=71428571)(
 input wire clk,rst,key_n,output reg short_press,long_press);
 reg meta,sync,stable,long_sent;reg [20:0] debounce_count;reg [26:0] hold_count;
 always @(posedge clk or posedge rst)begin
  if(rst)begin meta<=1;sync<=1;stable<=1;long_sent<=0;debounce_count<=0;hold_count<=0;short_press<=0;long_press<=0;end
  else begin
   meta<=key_n;sync<=meta;short_press<=0;long_press<=0;
   if(sync==stable)debounce_count<=0;
   else if(debounce_count==DEBOUNCE-1)begin
    stable<=sync;debounce_count<=0;
    if(sync && !stable)begin if(!long_sent)short_press<=1;hold_count<=0;long_sent<=0;end
    else begin hold_count<=0;long_sent<=0;end
   end else debounce_count<=debounce_count+1'b1;
   if(!stable && !long_sent && !(sync && debounce_count==DEBOUNCE-1))begin
    if(hold_count==LONG_CYCLES-1)begin long_press<=1;long_sent<=1;end
    else hold_count<=hold_count+1'b1;
   end
  end
 end
endmodule
