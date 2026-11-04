`timescale 1ns/1ps
module tb_music_fourbit;
parameter PREFILL=768,PIPELINE=1,STREAM=1;
reg sc=0,mc=0,pc=0,rst=1,song_reset=1;always #5 sc=~sc;always #7.5 mc=~mc;always #20 pc=~pc;
wire aq,av,ae,aw,sr,sv,rv,pop,playing,under,ready,bv,se,sreq,sreset,iv,ie,iw;
wire [31:0] alba,sample,data,lba;wire [7:0] bd,err;wire done,failed,sck;tri1 cs,mosi;wire[3:0]dat;assign cs=dat[3];wire miso=dat[0];
wire [12:0] wl,rl;wire [23:0] left,right;wire audio_valid,acr;
reg iq=0,ipending=0;reg [31:0] ilba=1088;integer image_bytes=0,image_sectors=0;
wire ar=rst||song_reset;
sd_native_bridge card(.sd_clk(sc),.clk(mc),.rst(rst||sreset),.SD_nCS(cs),.SD_DCLK(sck),.SD_MOSI(mosi),.SD_MISO(miso),.SD_D1(dat[1]),.SD_D2(dat[2]),
 .sd_init_done(ready),.sd_sec_read(sreq),.read_stream(STREAM!=0),.sd_sec_read_addr(lba),.sd_sec_read_data(bd),.sd_sec_read_data_valid(bv),.sd_sec_read_end(se),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0));
sd_native_fixture #(.DISK(1),.FOLDER("sim/fixtures/responsive")) fixture(rst,sck,mosi,dat,1'b0,1'b0);
sd_read_arbiter #(.TIMEOUT(2000000)) arb(mc,rst,ready,rst,iq,ilba,ar,aq,alba,wl<1536,iw,aw,iv,ie,av,ae,bv,se,sreq,lba,sreset);
fat32_media_stream #(.PREFETCH(PIPELINE),.IO_TIMEOUT(2000000)) reader(.clk(mc),.rst(ar),.enable(1'b1),.sd_ready(ready),.io_wait(aw),.video_mode(1'b0),
 .sector_req(aq),.sector_lba(alba),.byte_valid(av),.byte_data(bd),.sector_end(ae),.sample_valid(sv),.sample_ready(sr),.sample_data(sample),.done(done),.failed(failed),.error_code(err));
audio_fifo fifo(mc,pc,ar,sv,sample,sr,pop,rv,data,wl,rl,1'b0,1'b0);
pcm_player #(.PREFILL(PREFILL)) player(pc,ar,1'b1,rv,data,rl,pop,audio_valid,acr,left,right,playing,under,3'd4,1'b0);
integer n=0,total=0,round=0;time start_time;reg [31:0] expected;
always @(posedge mc)begin
 iq<=0;
 if(!rst && ready)begin
  if(!ipending)begin iq<=1;ipending<=1;image_bytes=0;end
  if(iv)begin
   // Image blocks 1089..1119 contain constant BGR pixels, header only at1088.
   if(ilba>1088 && bd!==((image_bytes+((ilba-1088)*512)-54)%3==0?8'h30:(image_bytes+((ilba-1088)*512)-54)%3==1?8'h60:8'h90))$fatal(1,"cross-owner image data");
   image_bytes=image_bytes+1;
  end
  if(ie)begin
   if(image_bytes!=512)$fatal(1,"image byte count");image_sectors=image_sectors+1;ipending<=0;ilba<=ilba==1119?1088:ilba+1;
  end
 end
 if(!ar && failed)$fatal(1,"WAV read error %h",err);
end
always @(posedge pc)if(!ar)begin
 if(under)$fatal(1,"PCM underrun while photo reads active");
 if(pop)begin
  expected={16'(n*97%30000-15000),16'(n*73%30000-15000)};
  if(data!==expected)$fatal(1,"PCM mismatch n%0d %h/%h",n,data,expected);
  if(n==0)$display("START round=%d prefill=%d pipeline=%d stream=%d latency_ns=%0t",round,PREFILL,PIPELINE,STREAM,$time-start_time);
  n=n+1;total=total+1;
 end
end
initial begin
 repeat(5)@(negedge mc);rst=0;wait(ready);repeat(5)@(negedge mc);start_time=$time;song_reset=0;
 wait(n==1500);@(negedge mc);song_reset=1;round=1;n=0;
 repeat(40)@(negedge mc);start_time=$time;song_reset=0;
 wait(n==4097);repeat(4)@(negedge pc);
 if(image_sectors<10 || total!=5597)$fatal(1,"coverage");
 $display("PASS MEDIA_LATENCY exact5597 stereo PCM samples, live song restart flush, concurrent photo sectors=%d, no underruns, CMD17=%d CMD18=%d CMD12=%d",image_sectors,fixture.cmd17s,fixture.cmd18s,fixture.cmd12s);$finish;
end
initial begin #300000000;$fatal(1,"timeout n=%d",n);end
endmodule
