// Restoring unsigned division, one reused bit-slice; no combinational divider.
module scale_divider(input wire clk,rst,start,input wire[23:0] numerator,
 input wire[12:0] denominator,output reg[23:0] quotient,
 output reg[12:0] remainder,output reg busy,done);
 reg[23:0] shift;reg[12:0] rem,den;reg[4:0] count;
 wire[13:0] trial={rem,shift[23]};
 always @(posedge clk or posedge rst)begin
  if(rst)begin quotient<=0;remainder<=0;busy<=0;done<=0;shift<=0;rem<=0;den<=1;count<=0;end
  else begin
   done<=0;
   if(start&&!busy)begin shift<=numerator;rem<=0;den<=denominator;count<=23;busy<=1;end
   else if(busy)begin
    shift<={shift[22:0],trial>={1'b0,den}};
    rem<=trial>={1'b0,den}?trial-den:trial;
    if(count==0)begin
     quotient<={shift[22:0],trial>={1'b0,den}};
     remainder<=trial>={1'b0,den}?trial-den:trial;busy<=0;done<=1;
    end else count<=count-1'b1;
   end
  end
 end
endmodule
