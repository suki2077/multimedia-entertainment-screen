`timescale 1ns/1ps
module tb_wire_reader;
 reg clk=0,rst=1;wire bv,se;wire [7:0]bd;
 always #7.5 clk=~clk;
 wire req,sv,done,failed;wire [31:0] lba,sample;wire [7:0] err;wire [5:0] state;
 reg [31:0] info[0:2],lbas[0:2047],expected[0:66815];reg [7:0] disk[0:1048575];
 integer cycles=0,n=0,pause_count=0,mode=0,count=0,i,index=-1,offset=0,first=0;
 reg active=0;string folder;
 wire sample_ready;wire vv,av;wire[31:0]vd;wire[15:0]ad;
 integer cool=0,group_words=0,begin_cycle=0,elapsed=0;integer multi_mode=1;
 wire card_ready,cs,sck,mosi,miso;
 sd_card_top #(.SPI_LOW_SPEED_DIV(0)) card(.clk(clk),.rst(rst),.SD_nCS(cs),.SD_DCLK(sck),.SD_MOSI(mosi),.SD_MISO(miso),
 .sd_init_done(card_ready),.sd_sec_read(req),.read_stream(multi_mode!=0),.sd_sec_read_addr(lba),.sd_sec_read_data(bd),
 .sd_sec_read_data_valid(bv),.sd_sec_read_end(se),.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
 sd_spi_fixture fixture(clk,rst,cs,sck,mosi,miso);
 av_unpacker unpack(clk,rst,sv,sample,sample_ready,vv,vd,cool==0,av,ad,1'b1);
 always @(posedge clk)begin
  if(cool!=0)cool<=cool-1;
  else if(vv)begin if(group_words==3)begin group_words<=0;cool<=36;end else group_words<=group_words+1;end
 end
 fat32_media_stream #(.INIT_TIMEOUT(200000),.IO_TIMEOUT(2000000)) dut(.clk(clk),.rst(rst),.enable(1'b1),.sd_ready(card_ready),.io_wait(1'b0),.video_mode(1'b1),
  .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
  .sample_valid(sv),.sample_ready(sample_ready),.sample_data(sample),.done(done),.failed(failed),.error_code(err),.debug_state(state));
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;
  if(n==1000 && pause_count<5000)pause_count<=pause_count+1;
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
   if((mode!=0 && mode!=3) || n!=66816)$fatal(1,"completion mismatch");
   elapsed=cycles-begin_cycle;$display("WIRE_READER multi=%0d effective_Bps=%0f CMD17=%0d CMD18=%0d CMD12=%0d",multi_mode,267264.0*1e9/(elapsed*15),fixture.cmd17s,fixture.cmd18s,fixture.cmd12s);
   if(multi_mode!=0 && 267264.0*1e9/(elapsed*15)<2004480)$fatal(1,"throughput target");
   $display("PASS fragmented FAT32 VIDEO.SAV: 66816 interleaved words, all bytes, EOF, bounded SD reads, indefinite consumer backpressure");$finish;
  end
 end
 initial begin
  if(!$value$plusargs("MULTI=%d",multi_mode))multi_mode=1;
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
 initial begin #1000000000;$fatal(1,"reader timeout");end
endmodule
