`timescale 1ns/1ps
module tb_photo_serial;
parameter PREFETCH=0;
reg clk=0,rst=1,bv=0,se=0;reg [7:0] bd=0;always #7.5 clk=~clk;
wire req,gv,done,failed;wire [31:0] lba;wire [20:0] addr;wire [127:0] data;wire [7:0] err;
integer cycle=0,groups=0,count,k,index,offset=0,waits=0,requests=0,prefetches=0;reg serving=0;
reg [31:0] info[0:2],lbas[0:2047];reg [7:0] disk[0:1048575];
wire ready=cycle%40==0;
fat32_bmp_loader #(.PREFETCH(PREFETCH),.IO_TIMEOUT(2000000)) dut(.clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.image_index(2'd0),
 .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),.group_valid(gv),.group_ready(ready),.group_addr(addr),.group_data(data),.done(done),.failed(failed),.error_code(err));
always @(negedge clk)begin
 bv=0;se=0;
 if(!rst)begin
  cycle=cycle+1;
  if(req)begin
   if(serving)$fatal(1,"overlap");index=-1;for(k=0;k<count;k=k+1)if(lbas[k]==lba)index=k;
   if(index<0)$fatal(1,"bad LBA %d",lba);requests=requests+1;
   if(dut.prefetch_busy)prefetches=prefetches+1;
   serving=1;offset=0;waits=100;
  end else if(serving)begin
   if(waits!=0)waits=waits-1;
   else if(offset<512)begin bv=1;bd=disk[index*512+offset];offset=offset+1;waits=21;end
   else begin se=1;serving=0;end
  end
  if(gv&&ready)begin
   if(data!=={4{32'h00906030}})$fatal(1,"pixel mismatch group=%d addr=%d data=%h",groups,addr,data);
   groups=groups+1;
  end
  if(failed)$fatal(1,"photo error %h",err);
  if(done)begin
   if(groups!=76800 || (PREFETCH && prefetches<400))$fatal(1,"completion/coverage");
   $display("PASS PHOTO_PIPELINE prefetch=%d cycles=%d groups=%d requests=%d pipelined=%d",PREFETCH,cycle,groups,requests,prefetches);$finish;
  end
 end
end
initial begin
 $readmemh("sim/fixtures/responsive/info.hex",info);count=info[0];
 $readmemh("sim/fixtures/responsive/lbas.hex",lbas,0,count-1);$readmemh("sim/fixtures/responsive/data.hex",disk,0,count*512-1);
 repeat(4)@(negedge clk);#1;rst=0;
end
initial begin #1000000000;$fatal(1,"timeout state=%d",dut.state);end
endmodule
