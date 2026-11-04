module key_press #(parameter DEBOUNCE=1428571)(input wire clk,rst,key_n,output reg pressed);
reg meta,sync,stable;reg [20:0] count;
always @(posedge clk or posedge rst) begin
 if(rst) begin meta<=1;sync<=1;stable<=1;count<=0;pressed<=0;end
 else begin
  meta<=key_n;sync<=meta;pressed<=0;
  if(sync==stable) count<=0;
  else if(count==DEBOUNCE-1) begin stable<=sync;count<=0;if(!sync) pressed<=1;end
  else count<=count+1'b1;
 end
end
endmodule
