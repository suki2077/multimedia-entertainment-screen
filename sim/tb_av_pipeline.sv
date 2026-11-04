`timescale 1ns/1ps
module tb_av_pipeline;
 wire [31:0] lba,sample,wd,frames,late_count;
 wire [9:0] x,y;
 reg mc=0,pc=0,rst=1;always #7.5 mc=~mc;always #20 pc=~pc;
 reg [3:0] restart=15;wire arst=rst || restart!=0;
 wire req,sv,sr,done,failed,we,re,lwe,lreq,lack,ready,ve,vo,packet_pending;
 wire vv,vr,av,ar,fv,pop,audio_tick,acr,ft,audio_under,audio_playing;
 wire [31:0] vd;wire [15:0] ad;wire [12:0] wl,rl;wire [31:0] paired,fd;wire pair_valid,pair_ready;
 wire [23:0] left_data,right_data;
 reg paused=0,pause_meta=0,pause_pixel=0,media_enable=0,ready_meta=0,ready_sync=0,pending_meta=0,pending_sync=0;
 integer pops=0,rendered=0,pause_cycles=0,wait_ticks=0;
 reg [15:0] mono[0:3199];
 time boundary_time=0;reg last_toggle=0,paused_since_boundary=0;
 reg [31:0] previous_frames=0;
 av_unpacker unpack(mc,rst,sv,sample,sr,vv,vd,vr,av,ad,ar);
 mono_pair pair(mc,rst,av,ad,ar,pair_valid,paired,pair_ready);
 audio_fifo fifo(mc,pc,rst,pair_valid,paired,pair_ready,pop,fv,fd,wl,rl,1'b0,1'b0);
 video_pcm_player player(pc,rst,media_enable,pause_pixel,fv,fd,rl,pop,audio_tick,acr,left_data,right_data,ft,audio_under,audio_playing,3'd4,pending_sync);
 always @(posedge pc)begin
  if(rst)begin pause_meta<=0;pause_pixel<=0;ready_meta<=0;ready_sync<=0;media_enable<=0;pending_meta<=0;pending_sync<=0;end
  else begin
   pause_meta<=paused;pause_pixel<=pause_meta;pending_meta<=packet_pending;pending_sync<=pending_meta;ready_meta<=ready;ready_sync<=ready_meta;
   if(x==0 && y==0 && ready_sync)media_enable<=1;
  end
 end
 always @(negedge mc)if(!rst)begin
  paused=pops==1700 && pause_cycles<3000000;
  if(paused)pause_cycles=pause_cycles+1;
 end
 integer expected_audio;reg advancing,ticking;
 always @(posedge pc)begin
  ticking=player.accumulator>=3119;advancing=0;expected_audio=0;
  if(!rst && ticking)begin
   advancing=media_enable && !pause_pixel && player.started && !player.frame_wait && (player.phase!=0 || fv);
   if(advancing)begin
    expected_audio=$signed(mono[(rendered/2)%3200])*256;
    if(pop!==((rendered%4)==3))$fatal(1,"FIFO consumption phase");
    if(player.phase==0 && fd!=={mono[((rendered/2)+1)%3200],mono[(rendered/2)%3200]})$fatal(1,"shared FIFO word packing/order");
    rendered=rendered+1;pops=rendered/2;
   end
  end
  #1;
  if(!rst && ticking)begin
   if($signed(left_data)!==expected_audio || right_data!==left_data)$fatal(1,"HDMI PCM mismatch");
   if(ft!==((rendered/3200)%2))$fatal(1,"media time drift");
   if(media_enable && player.started && !pause_pixel && player.frame_wait)wait_ticks=wait_ticks+1;
   if(audio_under)$fatal(1,"audio underrun in fast-card integration model");
   if(ft!=last_toggle)begin last_toggle=ft;boundary_time=$time;paused_since_boundary=0;end
   if(pause_pixel)paused_since_boundary=1;
  end
 end

 wire [20:0] wa,ra;wire [10:0] la,lra;wire [31:0] ld;wire [23:0] lq,rgb;
 wire [8:0] row,te,to;wire [7:0] err;
 reg bv=0,se=0;reg [7:0] bd=0;
 reg [31:0] info[0:2],lbas[0:2047],mem[0:1487999];reg [7:0] disk[0:1048575];
 integer byte_cycles=30;
 reg active=0;integer cycles=0,index=-1,offset=0,i,count,eofs=0,pixels=0,writes=0;
 reg [2:0] rv=0;reg [31:0] d0,d1,d2;
 wire hs,vs,de,under;
 function [23:0] expand565;input [15:0] c;
 begin expand565={c[15:11],c[15:13],c[10:5],c[10:9],c[4:0],c[4:2]};end endfunction
 integer px,py,native_x,native_y;reg [15:0] expected565;reg [23:0] expected_rgb,next_rgb;integer next_x,fraction,channel_shift,ca,cb;reg [15:0] next565;
 reg [1:0] checked_bank;
 fat32_media_stream reader(.clk(mc),.rst(arst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.video_mode(1'b1),
  .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
  .sample_valid(sv),.sample_ready(sr),.sample_data(sample),.done(done),.failed(failed),.error_code(err),.debug_state());
 video_store store(mc,rst,1'b1,1'b0,paused,ft,vv,vd,vr,we,wa,wd,re,ra,rv[2],d2,
   lreq,row,lack,lwe,la,ld,te,to,ve,vo,ready,frames,late_count,packet_pending);
 line_buffer #(.SMOOTH_VIDEO(1)) linebuf(.wclk(mc),.we(lwe),.waddr(la),.wdata(ld),.wvideo(1'b1),.rclk(pc),.raddr(lra),.rvideo(1'b1),.rfrac({x[1]^x[0],x[0],1'b0}),.q(lq));
 frame_video video(.pclk(pc),.rst(rst),.video_mode(1'b1),.view_reset(1'b0),.mem_ready(ready),.mem_failed(failed),
  .mem_verified(ready),.mem_init(1'b1),.mem_ack(lack),.tag_even(te),.tag_odd(to),.valid_even(ve),.valid_odd(vo),
  .req_toggle(lreq),.req_row(row),.line_raddr(lra),.line_q(lq),.hs(hs),.vs(vs),.de(de),.rgb(rgb),.underrun(under),.pixel_x(x),.pixel_y(y));
 always @(posedge mc)begin
  rv<={rv[1:0],re};if(re)d0<=mem[ra];d1<=d0;d2<=d1;
  if(we)begin
   if(ready && ((wa-1228800)/64800==store.display_bank))$fatal(1,"active buffer overwritten");
   mem[wa]<=wd;writes=writes+1;
  end
  if(rst)restart<=15;
  else if(restart!=0)restart<=restart-1'b1;
  else if(done)begin restart<=15;eofs=eofs+1;end
  if(!rst)begin
   cycles<=cycles+1;bv<=0;se<=0;
   if(req)begin
    if(active)$fatal(1,"overlapping sector requests");
    index=-1;for(i=0;i<count;i=i+1)if(lbas[i]==lba)index=i;
    if(index<0)$fatal(1,"unknown LBA");offset=0;active=1;
   end else if(active && cycles%byte_cycles==0)begin
    if(offset<512)begin bv<=1;bd<=disk[index*512+offset];offset=offset+1;end
    else begin active=0;se<=1;end
   end
   if(frames!=previous_frames)begin
    if(frames>1 && frames>(rendered/3200)+1)$fatal(1,"video ahead of audio");
    if(frames>1 && !paused_since_boundary && $time-boundary_time>16850000)$fatal(1,"AV phase exceeded one VS");
    $display("progress time=%0t frame=%0d samples=%0d late=%0d",$time,frames,pops,late_count);$fflush();
    previous_frames<=frames;
   end
   if(failed)$fatal(1,"reader failed %h",err);
  end
 end
 always @(posedge pc)begin
  px=x;py=y;
  #1;
  if(!rst && de && video.display_on)begin
   if(under || !video.use_memory)$fatal(1,"display row underflow at %0d,%0d",px,py);
   if(px==0 && py==0)checked_bank=store.display_bank;
   if(store.display_bank!=checked_bank)$fatal(1,"frame tearing");
   native_x=(px*3)/4;native_y=(py*9)/16;
   expected565=mem[1228800+store.display_bank*64800+native_y*240+native_x/2] >> ((native_x%2)*16);
   expected_rgb=expand565(expected565);next_x=native_x==479?479:native_x+1;fraction=(px*6)%8;
   next565=mem[1228800+store.display_bank*64800+native_y*240+next_x/2] >> ((next_x%2)*16);next_rgb=expand565(next565);
   for(channel_shift=0;channel_shift<24;channel_shift=channel_shift+8)begin
    ca=(expected_rgb>>channel_shift)&255;cb=(next_rgb>>channel_shift)&255;
    expected_rgb[channel_shift+:8]=(ca*(8-fraction)+cb*fraction+4)/8;
   end
   if(rgb!==expected_rgb)
    $fatal(1,"output pixel mismatch x=%0d y=%0d got=%h",px,py,rgb);
   pixels=pixels+1;
   if(frames>=6 && px==639 && py==479)begin
    if(eofs==0 || writes<388800 || pixels<640*480*3 || pops<8000 || pause_cycles!=3000000)$fatal(1,"loop coverage");
    if(wait_ticks>4)$fatal(1,"card too slow: %0d silent frame-boundary ticks",wait_ticks);
    $display("boundary_wait_ticks=%0d",wait_ticks);
    $display("PASS AV pipeline with exact PCM, pause/resume, audio-master VS alignment and loops: %0d output pixels checked, full-panel 640x480 mapping, floor(y*9/16) native rows, no tearing, no row underruns, %0d EOF loops, %0d displayed frames",pixels,eofs,frames);$finish;
   end
  end
 end
 initial begin
  if(!$value$plusargs("BYTE_CYCLES=%d",byte_cycles))byte_cycles=30;
  $readmemh("sim/fixtures/video/partition/mono.hex",mono);
  $readmemh("sim/fixtures/video/partition/info.hex",info);count=info[0];
  $readmemh("sim/fixtures/video/partition/lbas.hex",lbas,0,count-1);
  $readmemh("sim/fixtures/video/partition/data.hex",disk,0,count*512-1);
  repeat(4)@(negedge mc);rst=0;
 end
 initial begin #1000000000;$fatal(1,"pipeline deadline frames=%0d pixels=%0d",frames,pixels);end
endmodule

