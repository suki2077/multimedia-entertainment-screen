`timescale 1ns/1ps
module tb_av_unpacker;
 reg clk=0,rst=1;always #7 clk=~clk;
 integer words=0,audio_count=0,video_count=0,cycles=0;
 wire valid=words<66048 && cycles%13!=0;
 wire ready,av,vv;
 wire ar=cycles%17<12,vr=cycles%23<15;
 wire [15:0] ad;wire [31:0] vd;
 function [15:0] pal;input integer p,idx;begin pal=16'((idx*137+p*1777)^16'h9135);end endfunction
 function [31:0] data_at;input integer w;integer p,n,k;
 begin p=w/33024;n=w%33024;
  if(n<400)data_at={16'(p*800+n*2+1),16'(p*800+n*2)};
  else if(n<528)data_at={pal(p,(n-400)*2+1),pal(p,(n-400)*2)};
  else if(n<32928)begin k=(n-528)*4;data_at={8'(k+3+p*19),8'(k+2+p*19),8'(k+1+p*19),8'(k+p*19)};end
  else data_at=32'hdeadbeef;
 end endfunction
 wire [31:0] data=data_at(words);
 av_unpacker dut(clk,rst,valid,data,ready,vv,vd,vr,av,ad,ar);
 integer p,k;
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;
  if(av && ar)begin
   if(ad!==16'(audio_count))$fatal(1,"audio ordering %d",audio_count);
   audio_count<=audio_count+1;
  end
  if(vv && vr)begin
   p=video_count/64800;k=(video_count%64800)*2;
   if(vd!=={pal(p,(k+1+p*19)%256),pal(p,(k+p*19)%256)})$fatal(1,"palette/video ordering %d got %h",video_count,vd);
   video_count<=video_count+1;
  end
  if(valid && ready)words<=words+1;
  if(words==66048)begin
   if(audio_count!=1600 || video_count!=129600 || dut.word_index!=0 || dut.phase!=0)$fatal(1,"packet completion");
   $display("PASS two distinct palettes: 1600 PCM samples, 259200 exact decoded pixels, both palette halves and all indices, source stalls and independent video/audio backpressure");$finish;
  end
 end
 initial begin repeat(4)@(negedge clk);rst=0;end
 initial begin #20000000;$fatal(1,"unpack timeout");end
endmodule
