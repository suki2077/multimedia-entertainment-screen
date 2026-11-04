`timescale 1ns/1ps
module tb_sd_edges;
 tb_sd_multiread t();
 realtime rose=0,fell=0,delta,min_high=1.0e9,min_low=1.0e9;
 integer highs=0,lows=0;
 always @(posedge t.sck)if(t.ready && !t.cs && fell!=0)begin
  delta=$realtime-fell;
  if(delta<29.99)$fatal(1,"SD low phase too short %0f ns",delta);
  if(delta<min_low)min_low=delta;
  rose=$realtime;lows=lows+1;
 end
 always @(negedge t.sck)if(t.ready && !t.cs)begin
  if(rose!=0)begin
   delta=$realtime-rose;
   if(delta<14.99)$fatal(1,"SD high phase too short %0f ns",delta);
   if(delta<min_high)min_high=delta;
   highs=highs+1;
  end
  fell=$realtime;
 end
 final $display("PASS SD edge widths: high minimum=%0f ns low minimum=%0f ns, %0d/%0d edges; full sector/command checks in child bench",min_high,min_low,highs,lows);
endmodule
