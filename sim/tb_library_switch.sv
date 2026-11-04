`timescale 1ns/1ps
module tb_library_switch;
reg clk=0,rst=1,sw=1,np=0,pp=0,ok=0,home=0,ready=1,busy=0;always #5 clk=~clk;
wire requested,opened,restart,paused,an,ap;wire[2:0] page,cursor,music,video;wire[1:0] setting;wire setting_toggle;
library_switch #(.DEBOUNCE(4)) filter(clk,rst,sw,requested);
shell_control #(.LIBRARY(1),.LIBRARY_SWITCH(1)) s(.clk(clk),.rst(rst),.next_press(np),.prev_press(pp),.confirm_short(ok),.home_long(home),.page(page),.library_press(requested),.library_ready(ready),.media_busy(busy),.music_count(4'd8),.video_count(4'd8),.library_open(opened),.library_cursor(cursor),.music_selected(music),.video_selected(video),.file_restart(restart),.video_paused(paused),.album_next(an),.album_prev(ap),.setting_command(setting),.setting_toggle(setting_toggle));
reg vs=1,ct=0;reg[1:0] cmd=0;wire[1:0] bright;wire sound,period;wire[2:0] volume;
media_controls #(.DEBOUNCE_CYCLES(3)) c(.clk(clk),.rst(rst),.switches({1'b0,3'b111}),.vs(vs),.video_mode(1'b0),.setting_toggle(ct),.setting_command(cmd),.brightness(bright),.sound_enable(sound),.period_long(period),.volume(volume));
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task press(input integer key);begin @(negedge clk);case(key)0:np=1;1:pp=1;2:ok=1;3:home=1;endcase @(negedge clk);np=0;pp=0;ok=0;home=0;ticks(2);end endtask
task switch_to(input value);begin sw=value;ticks(10);end endtask
integer i;
initial begin
ticks(4);rst=0;ticks(10);if(requested||opened)$fatal(1,"startup false open");
repeat(4)begin sw=0;ticks(1);sw=1;ticks(4);end if(requested)$fatal(1,"bounce accepted");
switch_to(0);if(opened||page!=0)$fatal(1,"switch affected HOME");press(2);if(page!=1||!opened)$fatal(1,"album open on entry");
press(0);if(cursor!=1||an)$fatal(1,"browse cursor");press(2);if(opened||music!=1)$fatal(1,"confirm music");ticks(100);if(opened)$fatal(1,"ON auto reopened after confirmation");
switch_to(1);switch_to(0);if(!opened||cursor!=1)$fatal(1,"rearm");ready=0;press(0);if(cursor!=1)$fatal(1,"scan gating");switch_to(1);if(opened)$fatal(1,"OFF cannot cancel scan");ready=1;
press(3);press(0);press(2);if(page!=4)$fatal(1,"video entry");press(2);if(!paused)$fatal(1,"video pause");switch_to(0);if(!opened||!paused)$fatal(1,"video browse");switch_to(1);if(opened||!paused)$fatal(1,"cancel pause preservation");switch_to(0);press(0);busy=1;press(2);if(!opened||video!=0)$fatal(1,"busy commit accepted");busy=0;press(2);if(opened||paused||video!=1||music!=1)$fatal(1,"video commit/isolation");ticks(40);if(opened)$fatal(1,"reopened after commit");
press(3);if(opened||page!=0)$fatal(1,"HOME while ON");press(2);if(page!=4||opened)$fatal(1,"HOME confirmation isolation/rearm");switch_to(1);switch_to(0);if(!opened)$fatal(1,"video reopen after HOME");
if(period||bright!=3||volume!=4||!sound)$fatal(1,"SW changed media settings");cmd=2;ct=~ct;ticks(8);vs=0;ticks(2);vs=1;ticks(3);if(!period)$fatal(1,"interval no longer adjustable in settings");
$display("PASS both-edge SW debounce, HOME/media entry, music/video browsing and selection, confirm close/rearm, OFF cancel during scanning, busy gating, pause preservation, independent cursors, HOME isolation and retained UI interval control");$finish;end
initial begin #100000;$fatal(1,"timeout");end
endmodule
