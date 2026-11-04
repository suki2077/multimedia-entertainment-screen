// Active-low switch to ground, with pull-up. One filter serves both edges.
module library_switch #(parameter DEBOUNCE=1428571)(input wire clk,rst,sw_n,output wire requested);
 reg meta,sync,stable;reg [20:0] count;
 assign requested=!stable;
 always @(posedge clk or posedge rst)begin
  if(rst)begin meta<=1;sync<=1;stable<=1;count<=0;end
  else begin
   meta<=sw_n;sync<=meta;
   if(sync==stable)count<=0;
   else if(count==DEBOUNCE-1)begin stable<=sync;count<=0;end
   else count<=count+1'b1;
  end
 end
endmodule
