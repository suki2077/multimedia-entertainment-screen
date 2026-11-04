`timescale 1ns/1ps
module tb_shell;
reg clk=0,rst=1,key=1,np=0,pp=0;always #5 clk=~clk;
wire sp,lp;wire[2:0] page;wire[1:0] home,focus,command;wire paused;wire event_ui,an,ap,am,setting_event;
key_action #(.DEBOUNCE(3),.LONG_CYCLES(40)) k(clk,rst,key,sp,lp);
shell_control s(clk,rst,np,pp,sp,lp,page,home,focus,event_ui,an,ap,am,command,setting_event,paused,1'b0,1'b0,1'b0,4'd0,4'd0,,,,,);
integer shorts=0,longs=0,nexts=0,prevs=0,modes=0;
always @(posedge clk)begin
 if(sp)shorts=shorts+1;if(lp)longs=longs+1;
 if(an)nexts=nexts+1;if(ap)prevs=prevs+1;if(am)modes=modes+1;
end
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task next_key;begin np=1;ticks(1);np=0;ticks(2);end endtask
task prev_key;begin pp=1;ticks(1);pp=0;ticks(2);end endtask
task click;begin key=0;ticks(15);key=1;ticks(10);end endtask
task back;begin key=0;ticks(60);if(page!=0)$fatal(1,"HOME hold failed");ticks(60);key=1;ticks(10);end endtask
reg old_setting;
initial begin
ticks(3);rst=0;ticks(5);
// Bounce cannot enter album. A valid short press only confirms after release.
key=0;ticks(1);key=1;ticks(2);key=0;ticks(1);key=1;ticks(8);
if(shorts || longs || page!=0)$fatal(1,"bounce accepted");
key=0;ticks(15);if(page!=0)$fatal(1,"short fired before release");key=1;ticks(10);
if(page!=1 || shorts!=1)$fatal(1,"album entry");
next_key();prev_key();click();if(nexts!=1 || prevs!=1 || modes!=1)$fatal(1,"album events");
back();if(longs!=1 || shorts!=2 || modes!=1)$fatal(1,"hold repeated or also confirmed");
prev_key();if(home!=2 || nexts!=1 || prevs!=1)$fatal(1,"home wrapping/isolation");
click();if(page!=3)$fatal(1,"settings entry");
old_setting=setting_event;click();if(command!=0 || setting_event==old_setting)$fatal(1,"brightness command");
next_key();old_setting=setting_event;click();if(command!=1 || setting_event==old_setting)$fatal(1,"sound command");
next_key();click();if(command!=2)$fatal(1,"period command");
next_key();click();if(page!=0)$fatal(1,"settings return");
prev_key();click();if(page!=2)$fatal(1,"game entry");click();if(page!=2)$fatal(1,"short game confirm must stay inside arcade");
if(nexts!=1 || prevs!=1 || modes!=1)$fatal(1,"menu input leaked to media");
click();back();if(longs!=2 || page!=0)$fatal(1,"game global return");
// Long press while already HOME must never confirm on release.
back();if(longs!=3 || page!=0)$fatal(1,"HOME long caused entry");
// Video home card is the previous item from the game card.
prev_key();if(home!=3)$fatal(1,"VIDEO cursor");click();if(page!=4 || paused)$fatal(1,"VIDEO entry");
click();if(!paused)$fatal(1,"VIDEO pause");click();if(paused)$fatal(1,"VIDEO resume");
next_key();if(command!=1)$fatal(1,"VIDEO volume down");prev_key();if(command!=3)$fatal(1,"VIDEO volume up");
if(nexts!=1 || prevs!=1 || modes!=1)$fatal(1,"VIDEO keys leaked to album");back();if(page!=0)$fatal(1,"VIDEO HOME");
$display("PASS video entry/pause/resume/volume/HOME and shell debounce, release-only confirmation, one-shot long HOME, no release-confirm after hold, cursor wrap, settings commands and media isolation");$finish;
end
initial begin #200000;$fatal(1,"shell timeout");end
endmodule
