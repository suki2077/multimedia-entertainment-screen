`timescale 1ns/1ps
module tb_library_reader;
 reg clk=0,rst=1,bv=0,se=0;reg [7:0] bd=0;
 always #7 clk=~clk;
 wire req,sv,done,failed,ce,cd;wire [31:0] lba,sample;wire [7:0] err;wire [2:0] ci;wire [3:0] cc;wire [87:0] cn;
 reg [31:0] lbas[0:63],info[0:2];reg [7:0] disk[0:32767];
 integer cycles=0,n=0,count,i,index=-1,offset=0,selected=0,kind=0,seen=0,empty=0;
 reg active=0;string folder;reg [87:0] expected_name;
 fat32_media_stream #(.SELECTABLE(1),.INIT_TIMEOUT(2000),.IO_TIMEOUT(2000)) dut(
  .clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.video_mode(kind!=0),
  .selected_file(selected[2:0]),.catalog_entry(ce),.catalog_index(ci),.catalog_name(cn),.catalog_count(cc),.catalog_done(cd),
  .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
  .sample_valid(sv),.sample_ready(cycles%7<5),.sample_data(sample),.done(done),.failed(failed),.error_code(err),.debug_state());
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;bv<=0;se<=0;
  if(req)begin
   if(active)$fatal(1,"overlapping requests");
   index=-1;for(i=0;i<count;i=i+1)if(lbas[i]==lba)index=i;
   if(index<0)$fatal(1,"unknown LBA %0d",lba);
   offset=0;active=1;
  end else if(active && cycles%2==0)begin
   if(offset<512)begin bv<=1;bd<=disk[index*512+offset];offset=offset+1;end
   else begin active=0;se<=1;end
  end
  if(ce)begin
   if(ci!==seen || seen>=info[1])$fatal(1,"catalog ordinal %0d/%0d",ci,seen);
   expected_name={8'h41+8'(seen),56'h20202020202020,kind!=0?24'h534156:24'h574156};
   if(cn!==expected_name)$fatal(1,"wrong short filename %h expected %h",cn,expected_name);
   seen=seen+1;
  end
  if(sv && cycles%7<5)begin
   if(!cd || cc!==info[1] || seen!=info[1])$fatal(1,"catalog incomplete before playback");
   if(sample!==(32'h12340000+selected*256+n))$fatal(1,"selected payload mismatch got %h sel %0d n %0d",sample,selected,n);
   n=n+1;
   if(kind!=0 && n==4)begin $display("PASS video catalog/select %0d: %0d names, exact packet words",selected,seen);$finish;end
  end
  if(failed)begin
   if(empty!=0 && err==4 && cd && cc==0 && seen==0)begin $display("PASS empty catalogue");$finish;end
   $fatal(1,"reader failure %h",err);
  end
  if(done)begin
   if(n!=4 || seen!=info[1])$fatal(1,"completion mismatch");
   $display("PASS music catalog/select %0d: %0d names, exact PCM, EOF",selected,seen);$finish;
  end
 end
 initial begin
  if(!$value$plusargs("DIR=%s",folder))folder="sim/fixtures/library/music";
  if(!$value$plusargs("SELECT=%d",selected))selected=0;
  if(!$value$plusargs("KIND=%d",kind))kind=0;
  if(!$value$plusargs("EMPTY=%d",empty))empty=0;
  $readmemh({folder,"/info.hex"},info);count=info[0];
  $readmemh({folder,"/lbas.hex"},lbas,0,count-1);
  $readmemh({folder,"/data.hex"},disk,0,count*512-1);
  repeat(4)@(negedge clk);rst=0;
 end
 initial begin #10000000;$fatal(1,"catalog timeout");end
endmodule
