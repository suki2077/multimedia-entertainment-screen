`timescale 1ns/1ps
module tb_startup;
 reg mclk=0,clocks_ready=0;always #5 mclk=~mclk;
 reg[21:0] startup_count;reg mrst;integer i;
    always @(posedge mclk or negedge clocks_ready) begin
        if(!clocks_ready)begin startup_count<=0;mrst<=1;end
        else begin
            if(startup_count<22'd1428572) startup_count<=startup_count+1'b1;
            mrst<=(startup_count<22'd1428571);
        end
    end

 initial begin
  #1;clocks_ready=1;#1;clocks_ready=0;#1;
  if(mrst!==1||startup_count!==0)$fatal(1,"asynchronous reset");
  @(negedge mclk);clocks_ready=1;
  for(i=0;i<1428580;i=i+1)begin
   @(negedge mclk);
   if(mrst !== (startup_count<1428572))$fatal(1,"startup duration changed count=%d",startup_count);
  end
  #1;clocks_ready=0;#1;if(mrst!==1)$fatal(1,"clock loss reset");
  $display("PASS registered startup reset: exact 1428572 clock gate and asynchronous clock-loss assertion");$finish;
 end
endmodule
