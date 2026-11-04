`timescale 1ns/1ps
module tb_album20_reader;
 reg clk=0,rst=1,scan=1;always #5 clk=~clk;
 wire req,gv,done,failed,scan_done;wire [31:0] lba;wire [20:0] addr;wire [127:0] data;wire [4:0] count;wire [7:0] error;
 reg bv=0,se=0;reg [7:0] bd=0;reg [4:0] selected=0;
 fat32_bmp_loader #(.INDEX_BITS(5),.CATALOG(1),.IO_TIMEOUT(100000)) d(.clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.image_index(selected),
 .scan_only(scan),.scan_done(scan_done),.image_count(count),.sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
 .group_valid(gv),.group_ready(1'b1),.group_addr(addr),.group_data(data),.done(done),.failed(failed),.error_code(error));
 reg [31:0] info[0:1],lbas[0:1023];reg [7:0] bytes[0:524287];reg [1023:0] dir,path;
 integer k,j,sector,position,reqs=0,n,expected,checks=0,catalog_total=0;reg serving=0;
 always @(negedge clk)begin
  bv=0;se=0;
  if(rst)begin serving=0;position=0;end
  else if(serving)begin
   if(position<512)begin bv=1;bd=bytes[sector*512+position];position=position+1;end
   else begin se=1;serving=0;end
  end else if(req)begin
   sector=-1;for(k=0;k<info[0];k=k+1)if(lbas[k]==lba)sector=k;
   if(sector<0)$fatal(1,"unexpected sector %d",lba);
   serving=1;position=0;reqs=reqs+1;
  end
 end
 task reset_reader;begin rst=1;repeat(4)@(negedge clk);#1;rst=0;end endtask
 initial begin
  if(!$value$plusargs("DIR=%s",dir))$fatal(1,"DIR required");
  path={dir,"/info.hex"};$readmemh(path,info);path={dir,"/lbas.hex"};$readmemh(path,lbas,0,info[0]-1);path={dir,"/data.hex"};$readmemh(path,bytes,0,info[0]*512-1);
  reset_reader();wait(scan_done || failed);@(negedge clk);
  if(failed || count!==info[1])$fatal(1,"catalog count %d/%d error %h",count,info[1],error);
  catalog_total=count;
  for(n=0;n<info[1];n=n+1)begin
   scan=0;selected=n;reset_reader();wait(gv || failed);#1;
   expected=32'h00210040+n*32'h00030101;
   if(failed || addr!=0 || data!=={4{32'(expected)}})$fatal(1,"selected photo %d first group addr=%d data=%h expected=%h error=%h",n,addr,data,expected,error);
   checks=checks+1;
  end
  if(info[1]==20)begin
   scan=0;selected=20;reset_reader();wait(gv || failed);#1;
   if(!failed || error!=8'h04 || gv)$fatal(1,"out-of-range 21st photo not rejected: %h",error);
  end
  $display("PASS BMP catalog expected=%0d counted=%0d, invalid header/LFN/folder skip, multi-cluster root, %0d selected first pixel groups, 21st index rejected where applicable, requests=%0d",info[1],catalog_total,checks,reqs);$finish;
 end
 initial begin #2000000000;$fatal(1,"reader timeout state=%d n=%d",d.state,n);end
endmodule
