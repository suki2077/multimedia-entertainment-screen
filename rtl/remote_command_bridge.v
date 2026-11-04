// Bundled command held until next UART command. Minimum 7 bytes at 38400
// gives >1.8 ms between toggles, far longer than the destination synchronizer.
module remote_command_bridge(input wire pclk,prst,event_valid,
 input wire [3:0] event_command,input wire mclk,mrst,
 output wire valid,output reg [3:0] command);
 reg event_toggle;reg [3:0] held;
 always @(posedge pclk or posedge prst)begin
  if(prst)begin event_toggle<=0;held<=0;end
  else if(event_valid)begin held<=event_command;event_toggle<=~event_toggle;end
 end
 reg [2:0] pipe;reg seen;reg [3:0] meta;
 always @(posedge mclk or posedge mrst)begin
  if(mrst)begin pipe<=0;seen<=0;meta<=0;command<=0;end
  else begin pipe<={pipe[1:0],event_toggle};seen<=pipe[2];meta<=held;command<=meta;end
 end
 assign valid=pipe[2]!=seen;
endmodule
