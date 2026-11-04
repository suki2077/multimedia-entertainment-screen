`timescale 1ns/1ps
module tb_photo_clean;
reg clk=0,mclk=0,rst=1,vs=1;always #5 clk=~clk;always #7 mclk=~mclk;
reg np=0,pp=0,ok=0,home=0,lp=0;wire[2:0] page;wire[1:0] hs,ss,cmd;wire togg,uit,an,ap,am,vpause,lo,restart;wire[2:0] cursor,ms,vsel;
shell_control #(.LIBRARY(1),.LIBRARY_SWITCH(1),.PHOTO_CLEAN(1)) nav(.clk(mclk),.rst(rst),.next_press(np),.prev_press(pp),.confirm_short(ok),.home_long(home),.page(page),.home_selected(hs),.settings_selected(ss),.ui_toggle(uit),.album_next(an),.album_prev(ap),.album_mode(am),.setting_command(cmd),.setting_toggle(togg),.video_paused(vpause),.library_press(lp),.library_ready(1'b1),.media_busy(1'b0),.music_count(4'd2),.video_count(4'd2),.library_open(lo),.library_cursor(cursor),.music_selected(ms),.video_selected(vsel),.file_restart(restart));
wire[1:0] bright,fx;wire sound,period,clean;wire[2:0] vol;reg vm=0;
media_controls #(.DEBOUNCE_CYCLES(3),.PHOTO_CLEAN(1)) controls(.clk(clk),.rst(rst),.switches(4'd7),.vs(vs),.video_mode(vm),.setting_toggle(togg),.setting_command(cmd),.brightness(bright),.sound_enable(sound),.period_long(period),.volume(vol),.transition_mode(fx),.clean_photo(clean));
reg[9:0] x=0,y=0;reg[23:0] raw=0;wire[9:0] oy=(clean && page==1)?10'd1023:y;wire[23:0] params,wave,caption,shell;
player_ui #(.MAX_IMAGES(20)) a(.clk(clk),.rst(rst),.image_index(5'd0),.image_count(5'd20),.busy(1'b0),.auto_mode(1'b1),.brightness(bright),.sound_enable(sound),.period_long(period),.playing(1'b1),.failed(1'b0),.volume(vol),.error_code(8'd0),.x(x),.y(oy),.rgb_in(raw),.rgb_out(params));
audio_wave_overlay b(.clk(clk),.rst(rst),.vs(vs),.audio_valid(1'b1),.pcm(24'h700000),.x(x),.y(oy),.rgb_in(params),.rgb_out(wave));
subtitle_overlay c(.clk(clk),.rst(rst),.vs(vs),.rx_valid(1'b0),.rx_error(1'b0),.rx_data(8'd0),.tx_ready(1'b1),.x(x),.y(oy),.rgb_in(wave),.rgb_out(caption));
shell_overlay #(.LIBRARY(1),.MAX_IMAGES(20),.PHOTO_CLEAN(1)) d(.clk(clk),.rst(rst),.page(page[1:0]),.home_selected(hs),.settings_selected(ss),.brightness(bright),.sound_enable(sound),.period_long(period),.playing(1'b1),.photo_ready(1'b1),.image_index(5'd0),.image_count(5'd20),.meter_levels(32'h12345678),.x(x),.y(y),.rgb_in(caption),.rgb_out(shell),.volume(vol),.catalog_clk(mclk),.catalog_entry(1'b0),.catalog_type(1'b0),.catalog_index(3'd0),.catalog_name(88'd0),.library_open(lo),.library_type(1'b0),.library_ready(1'b1),.library_cursor(cursor),.library_count(4'd2),.vs(vs),.clean_photo(clean));
integer i,j,k,changed,clean_count,mode_events=0,f;reg[23:0] prev;
always @(posedge mclk)if(am)mode_events<=mode_events+1;
task waitp(input integer n);begin repeat(n)@(negedge clk);end endtask
task press(input integer key);begin @(negedge mclk);case(key)0:np=1;1:pp=1;2:ok=1;3:home=1;endcase @(negedge mclk);np=0;pp=0;ok=0;home=0;repeat(2)@(negedge mclk);end endtask
task frame;begin @(negedge clk);vs=0;waitp(3);vs=1;waitp(6);end endtask
task settings;begin if(page!=0)press(3);while(hs!=2)press(0);press(2);while(ss!=3)press(0);end endtask
task album;begin press(3);while(hs!=0)press(0);press(2);waitp(8);if(page!=1)$fatal(1,"album navigation");end endtask
task scan(input integer expect_clean);begin changed=0;clean_count=0;prev=0;
 for(j=0;j<480;j=j+1)for(i=0;i<640;i=i+1)begin
  @(negedge clk);x=i;y=j;raw={8'(i),8'(j),8'(i^j)};
  @(posedge clk);#1;
  if(caption!==raw)changed=changed+1;
  if(expect_clean && (j*640+i)>4)begin
   if(caption!==raw || params!==raw || wave!==raw)$fatal(1,"clean photo pixel changed at %0d,%0d",i,j);
   if(shell!==prev)$fatal(1,"shell passthrough/latency at %0d,%0d got=%h want=%h",i,j,shell,prev);
   clean_count=clean_count+1;
  end
  prev=raw;
 end
 if(expect_clean && clean_count!=307195)$fatal(1,"coverage");
 if(!expect_clean && changed<10000)$fatal(1,"normal overlays missing %0d",changed);
end endtask
initial begin waitp(6);rst=0;waitp(20);if(clean)$fatal(1,"default clean enabled");
 settings();press(2);waitp(12);if(clean)$fatal(1,"mode changed mid-frame");frame();if(!clean || page!=3)$fatal(1,"settings mode toggle/navigation");
 // Label/switch pixels are verified by tb_photo_clean_label.
 waitp(2000);
 album();frame();scan(1);press(0);press(1);press(2);if(mode_events!=1)$fatal(1,"album controls changed %0d",mode_events);
 // Media list must still open and close with SW4 while clean mode is active.
 @(negedge mclk);lp=1;repeat(4)@(negedge mclk);if(!lo)$fatal(1,"music list blocked");lp=0;repeat(4)@(negedge mclk);if(lo)$fatal(1,"list close");
 settings();press(2);waitp(12);if(!clean)$fatal(1,"off changed mid-frame");frame();if(clean)$fatal(1,"off failed");album();frame();scan(0);
 if({bright,sound,period,vol}!={2'd3,1'b1,1'b0,3'd4})$fatal(1,"media settings affected");
 $display("PASS pure-photo mode default OFF, settings navigation/frame-boundary toggle, 307195 exact clean pixels with existing overlay/shell pipeline, restoration of overlays, album controls and SW4 music list; brightness/audio/period unchanged");$finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
