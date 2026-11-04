// Pack successive mono samples into the existing stereo-word FIFO RAM.
module mono_pair(input wire clk,rst,input wire valid,input wire [15:0] data,output wire ready,
 output reg out_valid,output reg [31:0] out_data,input wire out_ready);
 reg half;reg [15:0] low;
 assign ready=!out_valid;
 always @(posedge clk or posedge rst)begin
  if(rst)begin half<=0;low<=0;out_valid<=0;out_data<=0;end
  else begin
   if(out_valid && out_ready)out_valid<=0;
   if(valid && ready)begin
    if(!half)begin low<=data;half<=1;end
    else begin out_data<={data,low};out_valid<=1;half<=0;end
   end
  end
 end
endmodule
