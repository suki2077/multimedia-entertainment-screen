// ASRPRO ASCII commands, 9600 8N1 at 66.666667 MHz. No newline required.
// Unexpected bytes resynchronize on the first character of a command.
module voice_command_rx #(parameter CLKS_PER_BIT=6944)(input wire clk,rst,rx,
 output reg valid,output reg [3:0] command);
 wire byte_valid,byte_error;wire [7:0] data;
 reg [5:0] state;reg [5:0] first;
 voice_uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx(.clk(clk),.rst(rst),.rx(rx),.valid(byte_valid),.error(byte_error),.data(data));
 always @* begin first=0;case(data)
  "W":first=6'd1;
  "M":first=6'd4;
  "N":first=6'd7;
  "P":first=6'd10;
  "V":first=6'd15;
  "B":first=6'd30;
  default:first=0;endcase end
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=0;valid<=0;command<=0;end
  else begin valid<=0;
   if(byte_error)state<=0;
   else if(byte_valid)begin state<=first;case(state)
    6'd1:case(data)
     "A":state<=6'd2;
     default:state<=first;endcase
    6'd2:case(data)
     "K":state<=6'd3;
     default:state<=first;endcase
    6'd3:case(data)
     "E":begin state<=0;valid<=1;command<=4'd0;end
     default:state<=first;endcase
    6'd4:case(data)
     "U":state<=6'd5;
     default:state<=first;endcase
    6'd5:case(data)
     "S":state<=6'd6;
     default:state<=first;endcase
    6'd6:case(data)
     "C":begin state<=0;valid<=1;command<=4'd1;end
     default:state<=first;endcase
    6'd7:case(data)
     "E":state<=6'd8;
     default:state<=first;endcase
    6'd8:case(data)
     "X":state<=6'd9;
     default:state<=first;endcase
    6'd9:case(data)
     "T":begin state<=0;valid<=1;command<=4'd2;end
     default:state<=first;endcase
    6'd10:case(data)
     "I":state<=6'd22;
     "L":state<=6'd13;
     "N":state<=6'd24;
     "P":state<=6'd26;
     "R":state<=6'd11;
     default:state<=first;endcase
    6'd11:case(data)
     "E":state<=6'd12;
     default:state<=first;endcase
    6'd12:case(data)
     "V":begin state<=0;valid<=1;command<=4'd3;end
     default:state<=first;endcase
    6'd13:case(data)
     "A":state<=6'd14;
     default:state<=first;endcase
    6'd14:case(data)
     "Y":begin state<=0;valid<=1;command<=4'd4;end
     default:state<=first;endcase
    6'd15:case(data)
     "I":state<=6'd16;
     "N":state<=6'd18;
     "O":state<=6'd28;
     "P":state<=6'd20;
     default:state<=first;endcase
    6'd16:case(data)
     "D":state<=6'd17;
     default:state<=first;endcase
    6'd17:case(data)
     "E":begin state<=0;valid<=1;command<=4'd5;end
     default:state<=first;endcase
    6'd18:case(data)
     "X":state<=6'd19;
     default:state<=first;endcase
    6'd19:case(data)
     "T":begin state<=0;valid<=1;command<=4'd6;end
     default:state<=first;endcase
    6'd20:case(data)
     "R":state<=6'd21;
     default:state<=first;endcase
    6'd21:case(data)
     "V":begin state<=0;valid<=1;command<=4'd7;end
     default:state<=first;endcase
    6'd22:case(data)
     "C":state<=6'd23;
     default:state<=first;endcase
    6'd23:case(data)
     "T":begin state<=0;valid<=1;command<=4'd8;end
     default:state<=first;endcase
    6'd24:case(data)
     "X":state<=6'd25;
     default:state<=first;endcase
    6'd25:case(data)
     "T":begin state<=0;valid<=1;command<=4'd9;end
     default:state<=first;endcase
    6'd26:case(data)
     "R":state<=6'd27;
     default:state<=first;endcase
    6'd27:case(data)
     "V":begin state<=0;valid<=1;command<=4'd10;end
     default:state<=first;endcase
    6'd28:case(data)
     "L":state<=6'd29;
     default:state<=first;endcase
    6'd29:case(data)
     "D":begin state<=0;valid<=1;command<=4'd12;end
     "U":begin state<=0;valid<=1;command<=4'd11;end
     default:state<=first;endcase
    6'd30:case(data)
     "R":state<=6'd31;
     default:state<=first;endcase
    6'd31:case(data)
     "D":state<=6'd33;
     "U":state<=6'd32;
     default:state<=first;endcase
    6'd32:case(data)
     "P":begin state<=0;valid<=1;command<=4'd13;end
     default:state<=first;endcase
    6'd33:case(data)
     "N":begin state<=0;valid<=1;command<=4'd14;end
     default:state<=first;endcase
    default:state<=first;endcase end
  end
 end
endmodule
