// Mode-3 SD SPI byte engine. FFFF selects negotiated 50 MHz; default divider
// values retain clk/(2*(div+2)). Sample MISO on the following falling-edge
// system clock, allowing the card a whole 20 ns period in high-speed mode.
module spi_master(input wire sys_clk,fast_read,rst,output wire nCS,
 output reg DCLK,output wire MOSI,input wire MISO,CPOL,CPHA,nCS_ctrl,
 input wire[15:0]clk_div,input wire wr_req,output wire wr_ack,
 input wire[7:0]data_in,output wire[7:0]data_out);
 localparam IDLE=0,TRANSFER=1,TAIL=2,ACK=3,SETTLE=4;
 reg[2:0]state;reg[15:0]count;reg[3:0]edge_no;reg[7:0]tx,rx;
 wire[15:0]limit=clk_div==16'hffff ? 16'd0:clk_div+1'b1;
 assign nCS=nCS_ctrl;assign MOSI=tx[7];assign data_out=rx;assign wr_ack=state==ACK;
 always @(posedge sys_clk or posedge rst)begin
  if(rst)begin state<=IDLE;count<=0;edge_no<=0;tx<=255;rx<=0;DCLK<=1;end
  else case(state)
   IDLE:begin
    DCLK<=1;count<=0;edge_no<=0;
    if(wr_req)begin tx<=data_in;rx<=0;state<=TRANSFER;end
   end
   TRANSFER:if(count==limit)begin
    count<=0;DCLK<=~DCLK;
    if(!edge_no[0] && edge_no!=0)begin rx<={rx[6:0],MISO};tx<={tx[6:0],1'b1};end
    if(edge_no==15)state<=TAIL;else edge_no<=edge_no+1'b1;
   end else count<=count+1'b1;
   TAIL:if(count==limit)begin count<=0;rx<={rx[6:0],MISO};state<=ACK;end else count<=count+1'b1;
   ACK:state<=fast_read?IDLE:SETTLE;
   SETTLE:state<=IDLE;
  endcase
 end
endmodule
