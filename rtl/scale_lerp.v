// Shared RGB888 linear interpolator: rounded Q8 weights, three small DSPs.
module scale_lerp(input wire clk,rst,start,input wire[23:0] a,b,
 input wire[7:0] fraction,output reg[23:0] result,output reg done);
 reg[2:0] stage;reg[23:0] base;
 reg signed[8:0] dr,dg,db;reg signed[8:0] weight;
 reg signed[17:0] pr,pg,pb;
 wire signed[18:0] sr=$signed({1'b0,base[23:16],8'd128})+pr;
 wire signed[18:0] sg=$signed({1'b0,base[15:8],8'd128})+pg;
 wire signed[18:0] sb=$signed({1'b0,base[7:0],8'd128})+pb;
 always @(posedge clk or posedge rst)begin
  if(rst)begin stage<=0;done<=0;result<=0;base<=0;dr<=0;dg<=0;db<=0;weight<=0;pr<=0;pg<=0;pb<=0;end
  else begin
   done<=0;
   case(stage)
    0:if(start)begin
     base<=a;dr<=$signed({1'b0,b[23:16]})-$signed({1'b0,a[23:16]});
     dg<=$signed({1'b0,b[15:8]})-$signed({1'b0,a[15:8]});
     db<=$signed({1'b0,b[7:0]})-$signed({1'b0,a[7:0]});weight<={1'b0,fraction};stage<=1;
    end
    1:begin pr<=dr*weight;pg<=dg*weight;pb<=db*weight;stage<=2;end
    2:begin result<={sr[15:8],sg[15:8],sb[15:8]};done<=1;stage<=0;end
    default:stage<=0;
   endcase
  end
 end
endmodule
