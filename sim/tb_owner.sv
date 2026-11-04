`timescale 1ns/1ps
module tb_owner;
 reg clk=0,rst=1,want=0;always #7 clk=~clk;
 wire owner,sw,quiet;
 media_owner #(.DRAIN_CYCLES(80)) d(clk,rst,want,owner,sw,quiet,1'b0);
 reg old=0;integer resets=0,drains=0,changes=0;
 always @(posedge clk)if(!rst)begin
  if(sw)resets=resets+1;if(quiet)drains=drains+1;
  #1;if(owner!=old)begin if(!sw)$fatal(1,"owner changed outside reset");old=owner;changes=changes+1;end
 end
 task transition(input v);begin
  @(negedge clk);want=v;@(posedge clk);#1;if(!quiet)$fatal(1,"new jobs not blocked immediately");
  repeat(45)@(negedge clk);if(sw || owner==v)$fatal(1,"drain phase skipped");
  wait(!quiet);#1;if(owner!=v)$fatal(1,"owner mismatch");
 end endtask
 initial begin repeat(3)@(negedge clk);rst=0;transition(1);transition(0);transition(1);
 if(changes!=3 || resets<90 || drains<230)$fatal(1,"handover coverage");
 $display("PASS owner handover: stop jobs, complete drain window, reset before/after owner change, both directions");$finish;end
endmodule
