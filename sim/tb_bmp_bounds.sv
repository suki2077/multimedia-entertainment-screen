`timescale 1ns/1ps
module tb_bmp_bounds;
reg clk=0,rst=1;always #7 clk=~clk;
wire gv;wire[20:0] ga;wire[127:0] gd;
fat32_bmp_loader dut(.clk(clk),.rst(rst),.enable(1'b0),.sd_ready(1'b0),.io_wait(1'b0),.image_index(2'd0),.byte_valid(1'b0),.byte_data(8'd0),.sector_end(1'b0),.group_valid(gv),.group_ready(1'b1),.group_addr(ga),.group_data(gd));
integer i,w,h,size,declared,need,pad,expected,k;
initial begin
 for(i=0;i<384;i=i+1)begin
  rst=1;repeat(2)@(negedge clk);rst=0;
  w=(i==0)?4096:((i*173)%4096+1);h=(i==0)?4096:((i*97)%4096+1);
  need=(w*3+(w%4))*h;size=54+need;declared=size;
  if(i%3==1)size=size-1;if(i%3==2)declared=declared-1;
  expected=(i%3==0);dut.state=23;dut.source_w=w;dut.source_h=h;dut.header_ok=1;
  dut.pixel_offset=54;dut.file_size=size;dut.valid_index=0;
  dut.header_mem[2]=declared;dut.header_mem[3]=declared>>8;dut.header_mem[4]=declared>>16;dut.header_mem[5]=declared>>24;
  repeat(5)@(negedge clk);
  if(dut.payload!==need)$fatal(1,"payload width/height mismatch %d %d",w,h);
  if(expected && dut.state!=13)$fatal(1,"valid BMP rejected case %d state %d",i,dut.state);
  if(!expected && dut.state!=6)$fatal(1,"truncated BMP accepted case %d state %d",i,dut.state);
 end
 $display("PASS 384 pipelined BMP length bounds: valid/truncated payload and declared-size checks, including 4096x4096");$finish;
end
endmodule
