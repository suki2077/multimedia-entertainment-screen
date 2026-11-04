// First block new jobs and drain complete application bursts/scanlines.
// Only the final 32 clocks reset clients/SD/FIFO; switch owner halfway through
// that reset window. The SDRAM controller and HDMI clocks keep running.
module media_owner #(parameter DRAIN_CYCLES=4096, RESTARTABLE=0)(input wire clk,rst,want_video,
 output reg video_owner,output reg switching,quiescing,input wire restart);
 reg target;reg [12:0] count;
 always @(posedge clk or posedge rst)begin
  if(rst)begin video_owner<=0;target<=0;count<=0;switching<=0;quiescing<=0;end
  else if(count!=0)begin
   count<=count-1'b1;
   if(count==33)switching<=1;
   if(count==1)begin switching<=0;quiescing<=0;end
   if(count==16)video_owner<=target;
  end else if(want_video!=video_owner || (RESTARTABLE && restart))begin target<=want_video;count<=DRAIN_CYCLES;quiescing<=1;switching<=0;end
 end
endmodule
