// One outstanding sector. The 100 MHz SPI engine holds each data byte until
// the next byte (>=330 ns); a three-edge event synchronizer captures it in
// the continuously running 66.667 MHz reader domain (<60 ns). No frame RAM.
// Request address/stream are bundled with a toggle and held until sector end.
module sd_read_bridge(
 input wire clk,sd_clk,rst,
 output wire SD_nCS,SD_DCLK,SD_MOSI,input wire SD_MISO,
 output reg sd_init_done,
 input wire sd_sec_read,read_stream,input wire [31:0] sd_sec_read_addr,
 output reg [7:0] sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
 input wire sd_sec_write,input wire [31:0] sd_sec_write_addr,
 input wire [7:0] sd_sec_write_data,output wire sd_sec_write_data_req,sd_sec_write_end);
 assign sd_sec_write_data_req=0;assign sd_sec_write_end=0; // read-only product
 reg [2:0] reset_pipe;
 always @(posedge sd_clk or posedge rst)
  if(rst)reset_pipe<=7;else reset_pipe<={reset_pipe[1:0],1'b0};
 wire srst=reset_pipe[2];
 reg request_toggle,busy,held_stream;reg [31:0] held_address;
 reg request_meta,request_sync,request_seen,request_pulse;
 reg native_stream;reg [31:0] native_address;
 wire native_ready,native_valid,native_end;wire [7:0] native_data;
 reg byte_toggle,end_toggle;reg [7:0] byte_hold;
 reg byte_meta,byte_sync,byte_seen,end_meta,end_sync,end_seen,ready_meta;
 always @(posedge sd_clk or posedge srst)begin
  if(srst)begin
   request_meta<=0;request_sync<=0;request_seen<=0;request_pulse<=0;
   native_stream<=0;native_address<=0;byte_toggle<=0;end_toggle<=0;byte_hold<=0;
  end else begin
   request_meta<=request_toggle;request_sync<=request_meta;request_pulse<=0;
   if(request_sync!=request_seen)begin
    request_seen<=request_sync;native_address<=held_address;native_stream<=held_stream;request_pulse<=1;
   end
   if(native_valid)begin byte_hold<=native_data;byte_toggle<=~byte_toggle;end
   if(native_end)end_toggle<=~end_toggle;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   request_toggle<=0;busy<=0;held_address<=0;held_stream<=0;
   byte_meta<=0;byte_sync<=0;byte_seen<=0;end_meta<=0;end_sync<=0;end_seen<=0;ready_meta<=0;
   sd_init_done<=0;sd_sec_read_data<=0;sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
  end else begin
   ready_meta<=native_ready;sd_init_done<=ready_meta;
   byte_meta<=byte_toggle;byte_sync<=byte_meta;end_meta<=end_toggle;end_sync<=end_meta;
   sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
   if(sd_sec_read && !busy && sd_init_done)begin
    held_address<=sd_sec_read_addr;held_stream<=read_stream;request_toggle<=~request_toggle;busy<=1;
   end
   if(byte_sync!=byte_seen)begin
    byte_seen<=byte_sync;
    if(busy)begin sd_sec_read_data<=byte_hold;sd_sec_read_data_valid<=1;end
   end
   if(end_sync!=end_seen)begin
    end_seen<=end_sync;
    if(busy)begin sd_sec_read_end<=1;busy<=0;end
   end
  end
 end
 sd_card_top #(.SPI_LOW_SPEED_DIV(123),.SPI_HIGH_SPEED_DIV(0)) core(
  .clk(sd_clk),.rst(srst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),.SD_MOSI(SD_MOSI),.SD_MISO(SD_MISO),
  .sd_init_done(native_ready),.sd_sec_read(request_pulse),.read_stream(native_stream),.sd_sec_read_addr(native_address),
  .sd_sec_read_data(native_data),.sd_sec_read_data_valid(native_valid),.sd_sec_read_end(native_end),
  .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
endmodule
