`timescale 1ns/1ps
module tb_av_reader;
 reg clk=0,rst=1,bv=0,se=0;reg [7:0] bd=0;
 always #7 clk=~clk;
 wire req,sv,done,failed;wire [31:0] lba,sample;wire [7:0] err;wire [5:0] state;
 reg [31:0] info[0:2],lbas[0:2047],expected[0:47103];reg [7:0] disk[0:1048575];
 integer cycles=0,n=0,pause_count=0,mode=0,count=0,i,index=-1,offset=0,first=0;
 reg active=0;string folder;
 wire sample_ready;wire vv,av;wire [31:0] vd;wire [15:0] ad;
 integer cool=0,group_words=0,begin_cycle=0,elapsed=0,token_wait=0;
 av_unpacker unpack(clk,rst,sv,sample,sample_ready,vv,vd,cool==0,av,ad,1'b1);
 always @(posedge clk)begin
  if(cool!=0)cool<=cool-1;
  else if(vv)begin
   if(group_words==3)begin group_words<=0;cool<=36;end
   else group_words<=group_words+1;
  end
 end
 fat32_media_stream #(.INIT_TIMEOUT(2000),.IO_TIMEOUT(10000)) dut(.clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.video_mode(1'b1),
  .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
  .sample_valid(sv),.sample_ready(sample_ready),.sample_data(sample),.done(done),.failed(failed),.error_code(err),.debug_state(state));
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;bv<=0;se<=0;
  if(n==1000 && pause_count<5000)pause_count<=pause_count+1;
  if(req)begin
   if(active)$fatal(1,"overlapping requests");
   index=-1;for(i=0;i<count;i=i+1)if(lbas[i]==lba)index=i;
   if(index<0)$fatal(1,"unknown LBA %0d",lba);
   offset=0;active=1;token_wait=3500;
  end else if(active && token_wait!=0)token_wait=token_wait-1;
  else if(active && cycles%40==0)begin
   if(offset<512)begin
    bv<=1;bd<=disk[index*512+offset];offset=offset+1;
    if(mode==2 && lba==first && offset==128)begin active=0;se<=1;end
   end else begin active=0;se<=1;end
  end
  if(sv && sample_ready)begin
   if(sample!==expected[n])$fatal(1,"payload mismatch %0d got %h expected %h",n,sample,expected[n]);
   if(n==0)begin_cycle=cycles;n=n+1;
  end
  if(failed)begin
   if((mode==1 && err==6)||(mode==2 && err==2))begin
    $display("PASS invalid video rejected mode=%0d error=%02x",mode,err);$finish;
   end
   $fatal(1,"unexpected reader failure %h",err);
  end
  if(done)begin
   if((mode!=0 && mode!=3) || n!=47104 )$fatal(1,"completion mismatch");
   elapsed=cycles-begin_cycle;$display("MEASURE two_packets_ns=%0d effective_Bps=%0f",elapsed*14,188416.0*1e9/(elapsed*14));
   $display("PASS fragmented FAT32 VIDEO.SAV: 47104 interleaved words, all bytes, EOF, bounded SD reads, indefinite consumer backpressure");$finish;
  end
 end
 initial begin
  if(!$value$plusargs("DIR=%s",folder))folder="sim/fixtures/video/superfloppy";
  if(!$value$plusargs("MODE=%d",mode))mode=0;
  $readmemh({folder,"/info.hex"},info);count=info[0];first=info[1];
  $readmemh({folder,"/lbas.hex"},lbas,0,count-1);
  $readmemh({folder,"/data.hex"},disk,0,count*512-1);
  $readmemh({folder,"/expected.hex"},expected);
  if(mode==3)begin
   // Move the valid MBR record from the first to the fourth primary slot.
   for(i=0;i<count;i=i+1)if(lbas[i]==0)begin
    for(integer j=0;j<16;j=j+1)begin disk[i*512+494+j]=disk[i*512+446+j];disk[i*512+446+j]=0;end
   end
  end
  if(mode==1)for(i=0;i<count;i=i+1)if(lbas[i]==first)disk[i*512]=0;
  repeat(4)@(negedge clk);rst=0;
 end
 initial begin #500000000;$fatal(1,"reader timeout");end
endmodule
