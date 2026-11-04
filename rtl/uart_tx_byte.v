module uart_tx_byte #(parameter CLKS_PER_BIT=217)(input wire clk,rst,valid,input wire [7:0] data,
 output wire ready,output wire tx);
 reg [9:0] shift;reg [3:0] bits_left;reg [15:0] count;
 assign ready=(bits_left==0);assign tx=ready?1'b1:shift[0];
 always @(posedge clk or posedge rst)begin
  if(rst)begin shift<=10'h3ff;bits_left<=0;count<=0;end
  else if(ready)begin
    if(valid)begin shift<={1'b1,data,1'b0};bits_left<=10;count<=CLKS_PER_BIT-1;end
  end else if(count!=0)count<=count-1'b1;
  else begin shift<={1'b1,shift[9:1]};bits_left<=bits_left-1'b1;count<=CLKS_PER_BIT-1;end
 end
endmodule
