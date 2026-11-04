// 25MHz / 217 = 115207 baud; 8 data bits, no parity, one stop bit.
module uart_rx_byte #(parameter CLKS_PER_BIT=217)(input wire clk,rst,rx,
 output reg valid,error,output reg [7:0] data);
 reg rm,rs;reg [1:0] state;reg [15:0] count;reg [2:0] bit_index;reg [7:0] shift;
 always @(posedge clk or posedge rst)begin
  if(rst)begin rm<=1;rs<=1;end else begin rm<=rx;rs<=rm;end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=0;count<=0;bit_index<=0;shift<=0;data<=0;valid<=0;error<=0;end
  else begin
   valid<=0;error<=0;
   case(state)
    0:if(!rs)begin state<=1;count<=(CLKS_PER_BIT/2)-1;end
    1:if(count!=0)count<=count-1'b1;else if(rs)state<=0;else begin state<=2;count<=CLKS_PER_BIT-1;bit_index<=0;end
    2:if(count!=0)count<=count-1'b1;else begin
       shift[bit_index]<=rs;count<=CLKS_PER_BIT-1;
       if(bit_index==7)state<=3;else bit_index<=bit_index+1'b1;
      end
    3:if(count!=0)count<=count-1'b1;else begin
       if(rs)begin data<=shift;valid<=1;end else error<=1;state<=0;
      end
   endcase
  end
 end
endmodule
