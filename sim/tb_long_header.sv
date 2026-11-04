`timescale 1ns/1ps
module tb_av_reader;
 reg clk=0,rst=1,bv=0,se=0;reg [7:0] bd=0;
 always #7 clk=~clk;
 wire req,sv,done,failed;wire [31:0] lba,sample;wire [7:0] err;wire [5:0] state;
 reg [31:0] info[0:2],lbas[0:2047],expected[0:66815];reg [7:0] disk[0:1048575];
 integer cycles=0,n=0,pause_count=0,mode=0,count=0,i,index=-1,offset=0,first=0;
 reg active=0;string folder;
 wire sample_ready=(cycles%47<35) && !(n==1000 && pause_count<5000);
 fat32_media_stream #(.INIT_TIMEOUT(2000),.IO_TIMEOUT(2000)) dut(.clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.video_mode(1'b1),
  .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
  .sample_valid(sv),.sample_ready(sample_ready),.sample_data(sample),.done(done),.failed(failed),.error_code(err),.debug_state(state));
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;bv<=0;se<=0;
  if(n==1000 && pause_count<5000)pause_count<=pause_count+1;
  if(req)begin
   if(active)$fatal(1,"overlapping requests");
   index=-1;for(i=0;i<count;i=i+1)if(lbas[i]==lba)index=i;
   if(index<0)$fatal(1,"unknown LBA %0d",lba);
   offset=0;active=1;
  end else if(active && cycles%2==0)begin
   if(offset<512)begin
    bv<=1;bd<=disk[index*512+offset];offset=offset+1;
    if(mode==2 && lba==first && offset==128)begin active=0;se<=1;end
   end else begin active=0;se<=1;end
  end
  if(sv && sample_ready)begin
   if(!dut.video_meta_valid || dut.video_total_frames!==((mode==4)?15'd27000:15'd2))$fatal(1,"bad video length metadata");
   if(sample!==expected[n])$fatal(1,"payload mismatch %0d got %h expected %h",n,sample,expected[n]);
   n=n+1;
  end
  if(mode==4 && n==40000)begin $display("PASS 30-minute header accepted, first 40000 words exact");$finish;end
  if(failed)begin
   if(((mode==1 || mode==5 || mode==6) && err==6)||(mode==2 && err==2))begin
    $display("PASS invalid video rejected mode=%0d error=%02x",mode,err);$finish;
   end
   $fatal(1,"unexpected reader failure %h",err);
  end
  if(done)begin
   if((mode!=0 && mode!=3) || n!=66816 || pause_count!=5000)$fatal(1,"completion mismatch");
   $display("PASS fragmented FAT32 VIDEO.SAV: 66816 interleaved words, all bytes, EOF, bounded SD reads, indefinite consumer backpressure");$finish;
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
  if(mode==6)for(i=0;i<count;i=i+1)if(lbas[i]==first)begin disk[i*512+8]=8'h90;disk[i*512+9]=1;end
  if(mode==1)for(i=0;i<count;i=i+1)if(lbas[i]==first)disk[i*512]=0;
  if(mode==4 || mode==5)begin
   for(i=0;i<count;i=i+1)begin
    if(lbas[i]==first)begin
     {disk[i*512+19],disk[i*512+18],disk[i*512+17],disk[i*512+16]}=(mode==4)?32'd27000:32'd27001;
     {disk[i*512+23],disk[i*512+22],disk[i*512+21],disk[i*512+20]}=((mode==4)?32'd27000:32'd27001)*32'd133632;
    end
    for(integer j=0;j<512;j=j+32)if({disk[i*512+j],disk[i*512+j+1],disk[i*512+j+2],disk[i*512+j+3],disk[i*512+j+4],disk[i*512+j+5],disk[i*512+j+6],disk[i*512+j+7],disk[i*512+j+8],disk[i*512+j+9],disk[i*512+j+10]}==88'h564944454f202020534156)
     {disk[i*512+j+31],disk[i*512+j+30],disk[i*512+j+29],disk[i*512+j+28]}=((mode==4)?32'd27000:32'd27001)*32'd133632+512;
   end
  end
  repeat(4)@(negedge clk);rst=0;
 end
 initial begin #100000000;$fatal(1,"reader timeout");end
endmodule
