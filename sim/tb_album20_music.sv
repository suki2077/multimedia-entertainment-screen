`timescale 1ns/1ps
module tb_album20_music;
 reg mc=0,pc=0,rst=1;always #7.5 mc=~mc;always #20 pc=~pc;
 reg[3:0] restart=15,image_restart=0;reg catalog_mode=1,catalog_finished=0;wire scan_done;wire [4:0] scan_count;
 wire irst=rst || image_restart!=0;wire arst=rst||restart!=0;
 always @(posedge mc)begin
  if(rst)begin catalog_mode<=1;catalog_finished<=0;image_restart<=0;end
  else if(catalog_mode && scan_done)begin
   if(scan_count!=4)$fatal(1,"shared catalog count %d",scan_count);
   catalog_mode<=0;catalog_finished<=1;image_restart<=15;
  end else if(image_restart!=0)image_restart<=image_restart-1'b1;
 end
 wire iq,aq,iv,ie,av,ae,iw,aw,sreq,sreset,idone,ifail,adone,afail;
 wire[31:0] ilba,alba,slba;reg sv=0,se=0;reg[7:0] sb;
 wire gv,gr;wire[20:0] ga;wire[127:0] gd;wire[7:0] ierr,aerr;
 wire sample_valid,sample_ready,rv,pop,audio_valid,acr,playing,under;
 wire[31:0] sample,fdata;wire[12:0] wl,rl;wire[23:0] left,right;
 integer cycle=0,count,index=-1,offset=0,lo,hi,mid,groups=0,n=0,loops=0,fd,minlevel=4096,ireads=0,areads=0;
 reg active=0;reg[31:0] lbas[0:16383];reg[7:0] disk[0:8388607];reg[31:0] expected;
 assign gr=(cycle%40==0);
 sd_read_arbiter #(.TIMEOUT(200000)) arb(mc,rst,1'b1,irst,iq,ilba,arst,aq,alba,wl<1536,iw,aw,iv,ie,av,ae,sv,se,sreq,slba,sreset);
 fat32_bmp_loader #(.IO_TIMEOUT(1000000),.INDEX_BITS(5),.CATALOG(1)) image(
  .clk(mc),.rst(irst),.scan_only(catalog_mode),.scan_done(scan_done),.image_count(scan_count),.enable(1'b1),.sd_ready(1'b1),.io_wait(iw),.image_index(5'd1),
  .sector_req(iq),.sector_lba(ilba),.byte_valid(iv),.byte_data(sb),.sector_end(ie),
  .group_valid(gv),.group_ready(gr),.group_addr(ga),.group_data(gd),.done(idone),.failed(ifail),.error_code(ierr),.debug_state());
 fat32_media_stream #(.IO_TIMEOUT(1000000)) music(
  .clk(mc),.rst(arst),.enable(1'b1),.sd_ready(1'b1),.io_wait(aw),.video_mode(1'b0),.sector_req(aq),.sector_lba(alba),
  .byte_valid(av),.byte_data(sb),.sector_end(ae),.sample_valid(sample_valid),.sample_ready(sample_ready),
  .sample_data(sample),.done(adone),.failed(afail),.error_code(aerr),.debug_state());
 audio_fifo fifo(mc,pc,rst,sample_valid,sample,sample_ready,pop,rv,fdata,wl,rl,1'b0,1'b0);
 pcm_player player(pc,rst,1'b1,rv,fdata,rl,pop,audio_valid,acr,left,right,playing,under,3'd4);
 always @(posedge mc)begin
  cycle<=cycle+1;sv<=0;se<=0;
  if(rst)restart<=15;else if(restart!=0)restart<=restart-1'b1;else if(adone)begin restart<=15;loops<=loops+1;end
  if(!rst)begin
   if(ifail||afail)$fatal(1,"read error BMP=%02x WAV=%02x",ierr,aerr);
   if(sreset)$fatal(1,"unexpected SD reset");
   if(gv&&gr)begin $fdisplay(fd,"%06x %032x",ga,gd);groups<=groups+1;end
   if(sreq)begin
    if(active)$fatal(1,"overlapping sector transaction");active=1;offset=0;
    lo=0;hi=count-1;index=-1;
    while(lo<=hi)begin mid=(lo+hi)/2;if(lbas[mid]==slba)begin index=mid;lo=hi+1;end else if(lbas[mid]<slba)lo=mid+1;else hi=mid-1;end
    if(index<0)$fatal(1,"unknown LBA %d",slba);
    if(arb.owner)areads<=areads+1;else ireads<=ireads+1;
   end else if(active&&cycle%64==0)begin
    if(offset<512)begin sv<=1;sb<=disk[index*512+offset];offset=offset+1;end
    else begin active=0;se<=1;end
   end
   if(n>=9000 && groups>=20000)begin
    if(!catalog_finished)$fatal(1,"catalog phase incomplete");
    if(loops<2)$fatal(1,"insufficient EOF loop coverage");
    $display("PASS 20-capable catalog scan then SCALE+MUSIC: %0d scaled image pixels during %0d PCM samples, %0d loops, zero underruns; image/audio sectors %0d/%0d, min FIFO %0d",groups*4,n,loops,ireads,areads,minlevel);$fclose(fd);$finish;
   end
   if(cycle>35000000)$fatal(1,"shared timeout groups=%d samples=%d",groups,n);
  end
 end
 always @(posedge pc)if(!rst)begin
  if(under)$fatal(1,"audio underrun during scaled BMP load");
  if(playing&&rl<minlevel)minlevel=rl;
  if(pop)begin
   expected={16'((n%4097)*97+1234),16'((n%4097)*73-16000)};
   if(fdata!==expected)$fatal(1,"PCM sequence sample %d got %h expected %h",n,fdata,expected);
   #1;if(left!=={expected[15:0],8'd0}||right!=={expected[31:16],8'd0})$fatal(1,"HDMI PCM data mismatch");
   n=n+1;
  end
 end
 initial begin
  if(!$value$plusargs("COUNT=%d",count))$fatal;
  $readmemh("sim/fixtures/shared/lbas.hex",lbas,0,count-1);
  $readmemh("sim/fixtures/shared/data.hex",disk,0,count*512-1);
  fd=$fopen("build/album20_music.txt","w");#101;rst=0;
 end
endmodule
