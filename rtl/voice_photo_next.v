// Receive the ASRPRO's 9600-baud ASCII PNXT command in the memory clock domain.
// A four-state matcher handles adjacent commands without a newline or 24-bit shift register.
module voice_photo_next #(parameter CLKS_PER_BIT=6944)(
 input wire clk, rst, rx, output reg next_photo
);
 wire valid, error;
 wire [7:0] data;
 reg [1:0] match_state;
 voice_uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx(
  .clk(clk), .rst(rst), .rx(rx), .valid(valid), .error(error), .data(data));
 always @(posedge clk or posedge rst) begin
  if (rst) begin match_state <= 0; next_photo <= 0; end
  else begin
   next_photo <= 0;
   if (error) match_state <= 0;
   else if (valid) begin
    case (match_state)
     0: match_state <= (data == "P") ? 1 : 0;
     1: match_state <= (data == "N") ? 2 : (data == "P") ? 1 : 0;
     2: match_state <= (data == "X") ? 3 : (data == "P") ? 1 : 0;
     3: begin
      next_photo <= (data == "T");
      match_state <= (data == "P") ? 1 : 0;
     end
    endcase
   end
  end
 end
endmodule

// 25MHz / 217 = 115207 baud; 8 data bits, no parity, one stop bit.
module voice_uart_rx #(parameter CLKS_PER_BIT=217)(input wire clk,rst,rx,
 output reg valid,error,output reg [7:0] data);
 reg rm,rs;reg [1:0] state;reg [$clog2(CLKS_PER_BIT+1)-1:0] count;reg [2:0] bit_index;reg [7:0] shift;
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
