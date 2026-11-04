`timescale 1ns/1ps
module tb_photo_fourbit;
reg clk=0,sc=0,rst=1;always #7.5 clk=~clk;always #5 sc=~sc;
wire req,bv,se,ready,gv,done,failed,sck;tri1 cs,mosi;wire[3:0]dat;assign cs=dat[3];wire miso=dat[0];wire[7:0]bd,err;
wire [31:0]lba;wire [20:0]addr;wire[127:0]data;
integer stream=1,cycle=0,groups=0,first_cycle=0;
sd_native_bridge card(.sd_clk(sc),.clk(clk),.rst(rst),.SD_nCS(cs),.SD_DCLK(sck),.SD_MOSI(mosi),.SD_MISO(miso),.SD_D1(dat[1]),.SD_D2(dat[2]),.sd_init_done(ready),
 .sd_sec_read(req),.read_stream(stream!=0),.sd_sec_read_addr(lba),.sd_sec_read_data(bd),.sd_sec_read_data_valid(bv),.sd_sec_read_end(se),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0));
sd_native_fixture #(.DISK(1),.FOLDER("sim/fixtures/responsive")) fixture(rst,sck,mosi,dat,1'b0,1'b0);
fat32_bmp_loader #(.IO_TIMEOUT(2000000)) dut(.clk(clk),.rst(rst),.enable(1'b1),.sd_ready(ready),.io_wait(1'b0),.image_index(2'd0),
 .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),.group_valid(gv),.group_ready(cycle%40==0),.group_addr(addr),.group_data(data),.done(done),.failed(failed),.error_code(err));
always @(negedge clk)if(!rst)begin
 cycle=cycle+1;
 if(ready && first_cycle==0)first_cycle=cycle;
 if(gv&&cycle%40==0)begin
  if(data!=={4{32'h00906030}})$fatal(1,"pixel mismatch at %d addr%0d data%h",groups,addr,data);
  groups=groups+1;
  if(groups%16384==0)begin $display("photo native stream=%d groups=%d",stream,groups);$fflush();end
 end
 if(failed)$fatal(1,"photo error %h",err);
 if(done)begin
  if(groups!=76800)$fatal(1,"incomplete frame");
  $display("PASS PHOTO_NATIVE stream=%d cycles=%d groups=%d CMD17=%d CMD18=%d CMD12=%d",stream,cycle-first_cycle,groups,fixture.cmd17s,fixture.cmd18s,fixture.cmd12s);$finish;
 end
end
initial begin
 if(!$value$plusargs("STREAM=%d",stream))stream=1;
 repeat(5)@(negedge clk);rst=0;
end
initial begin #1000000000;$fatal(1,"photo timeout");end
endmodule
