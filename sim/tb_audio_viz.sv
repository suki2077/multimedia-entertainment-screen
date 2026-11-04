`timescale 1ns/1ps
module tb_audio_viz;
 reg clk=0,rst=1,vs=1,audio_valid=0;always #5 clk=~clk;
 reg[23:0]pcm=0,rgb_in=24'h808080;reg[9:0]x=0,y=0;wire[23:0]rgb_out;
 reg paused=0;wire[23:0]hud;
 integer i,j,fd,xx,yy;reg[3:0]profile[0:31];reg[7:0]amp;
 audio_wave_overlay dut(clk,rst,vs,audio_valid,pcm,x,y,rgb_in,rgb_out);
 video_hud vh(x,y,rgb_in,paused,1'b1,1'b0,3'd3,10'd0,16'd0,16'd0,hud);
 task sample;input[23:0]v;begin
  @(negedge clk);pcm=v;audio_valid=1;@(negedge clk);audio_valid=0;
 end endtask
 task impulse_frame;input[23:0]v;integer k,n;begin
  for(k=0;k<32;k=k+1)for(n=0;n<24;n=n+1)sample(n==7?v:24'd0);
  if(!dut.capture_done)$fatal(1,"capture must contain all 768 audio samples");
 end endtask
 task publish;begin
  @(negedge clk);vs=0;@(negedge clk);vs=1;
  wait(dut.updating);wait(!dut.updating);repeat(3)@(negedge clk);
 end endtask
 task pixel;input[9:0]px,py;input[23:0]expected;begin
  @(negedge clk);x=px;y=py;@(posedge clk);#1;
  if(rgb_out!==expected)$fatal(1,"pixel %0d,%0d got %h expected %h",px,py,rgb_out,expected);
 end endtask
 task uniform_state;input[3:0]height,peak;integer k;reg[11:0]s;begin
  for(k=0;k<32;k=k+1)begin s=dut.samples[{dut.display_bank,k[4:0]}];
   if(s[3:0]!==height || s[7:4]!==peak)$fatal(1,"state col=%0d got=%h expected height=%0d peak=%0d",k,s,height,peak);
  end
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  impulse_frame(24'h400000);
  if(dut.display_valid)$fatal(1,"incomplete frame exposed");
  publish();uniform_state(9,9);
  pixel(67,436,24'h28decf);pixel(67,412,24'h66b9f1);pixel(67,372,24'hf0b1b3);
  pixel(67,365,24'hffd8b2);pixel(78,436,24'h151c28);pixel(67,450,24'h808080);
  $display("PASS peak windows retain impulses missed by point decimation; gradient, gaps, floating cap and subtitle pixels");
  impulse_frame(24'hc00000);uniform_state(9,9);publish();uniform_state(9,9);
  impulse_frame(24'd0);publish();uniform_state(8,9);
  for(i=0;i<44;i=i+1)begin impulse_frame(24'd0);publish();end
  uniform_state(0,0);pixel(67,436,24'h808080);
  impulse_frame(24'h800000);publish();uniform_state(12,12);
  $display("PASS negative PCM, bank isolation, release smoothing, slow peak decay, silence and signed saturation");
  @(negedge clk);x=34;y=30;paused=0;#1;if(hud!==24'h2c3746)$fatal(1,"pause action gap");
  x=38;y=24;#1;if(hud!==24'hecbb86)$fatal(1,"playing must show pause bars");
  paused=1;#1;if(hud!==24'h2c3746)$fatal(1,"paused play triangle shape");
  x=34;y=30;#1;if(hud!==24'h66dfbd)$fatal(1,"paused must show play triangle");
  $display("PASS video transport icons: playing offers pause, paused offers play");
  if($test$plusargs("RENDER"))begin
   @(negedge clk);rst=1;repeat(4)@(negedge clk);rst=0;
   // Deterministic test PCM profile; rendered by the actual RTL pixel path.
   for(i=0;i<32;i=i+1)begin
    case(i)
     0:profile[i]=5;1:profile[i]=3;2:profile[i]=4;3:profile[i]=7;
     4:profile[i]=10;5:profile[i]=12;6:profile[i]=9;7:profile[i]=6;
     8:profile[i]=4;9:profile[i]=3;10:profile[i]=5;11:profile[i]=8;
     12:profile[i]=11;13:profile[i]=7;14:profile[i]=5;15:profile[i]=3;
     16:profile[i]=2;17:profile[i]=4;18:profile[i]=7;19:profile[i]=9;
     20:profile[i]=6;21:profile[i]=4;22:profile[i]=5;23:profile[i]=8;
     24:profile[i]=10;25:profile[i]=7;26:profile[i]=5;27:profile[i]=3;
     28:profile[i]=4;29:profile[i]=6;30:profile[i]=4;31:profile[i]=2;
    endcase
   end
   for(j=0;j<16;j=j+1)begin
    for(i=0;i<32;i=i+1)begin
     amp=profile[i]>=11?profile[i]*8:(profile[i]-1)*8;
     repeat(24)sample({amp,16'd0});
    end
    publish();
   end
   for(j=0;j<2;j=j+1)begin
    for(i=0;i<32;i=i+1)begin
     amp=profile[i]>=11?profile[i]*8:(profile[i]-1)*8;
     amp=amp>24?amp-24:0;repeat(24)sample({amp,16'd0});
    end
    publish();
   end
   rgb_in=24'h101828;
   fd=$fopen("preview/gradient_equalizer.ppm","wb");$fwrite(fd,"P6\n512 104\n255\n");
   for(yy=340;yy<444;yy=yy+1)for(xx=64;xx<576;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;@(posedge clk);#1;
    if(^rgb_out===1'bx)$fatal(1,"unknown rendered pixel");
    $fwrite(fd,"%c%c%c",rgb_out[23:16],rgb_out[15:8],rgb_out[7:0]);
   end
   $fclose(fd);
  end
  $display("PASS audio visualizer and video action icons");$finish;
 end
 initial begin #20000000;$fatal(1,"deadline");end
endmodule

