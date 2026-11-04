`timescale 1ns/1ps
module tb_cache_control;
reg clk=0,rst=1,init=0,np=0,pp=0,mp=0,period=0,active=1,swapped=0,lf=0,fatal=0;
always #5 clk=~clk;
reg[1:0] shown=0;reg[3:0] valid=0;wire[1:0] selected;wire busy,started,reset_loader,begin_job,auto_mode,all_failed,bg,promote;
cache_album_control #(.TICK_CYCLES(2),.HOLD_TICKS(200),.HOLD_TICKS_LONG(400)) d(
.clk(clk),.rst(rst),.init_done(init),.next_press(np),.prev_press(pp),.mode_press(mp),.period_long(period),.presentation_active(active),.swapped(swapped),.load_failed(lf),.fatal_error(fatal),.displayed(shown),.cache_valid(valid),.selected(selected),.busy(busy),.started(started),.loader_reset(reset_loader),.begin_load(begin_job),.auto_mode(auto_mode),.all_failed(all_failed),.prefetch(bg),.promote(promote),.scan_done(1'b0),.scan_count(5'd4));
integer starts=0,n,saved;reg[1:0] expected;
always @(posedge clk)if(begin_job)starts=starts+1;
task job(input[1:0]index,input background);begin
 wait(begin_job);#1;if(selected!==index || bg!==background)$fatal(1,"wrong job idx=%d bg=%d expected=%d/%d",selected,bg,index,background);
 @(negedge clk);wait(!begin_job);
end endtask
task finish_bg(input integer index);begin wait(!reset_loader);@(negedge clk);valid[index]=1;end endtask
task finish_fg(input[1:0]index,input cached);integer j;begin
 if(cached)begin repeat(72)begin @(negedge clk);if(!reset_loader)$fatal(1,"cached hit enabled card loader");end end
 else wait(!reset_loader);
 @(negedge clk);valid[index]=1;shown=index;swapped=1;@(negedge clk);swapped=0;
end endtask
task next_button;begin @(negedge clk);np=1;@(negedge clk);np=0;end endtask
task prev_button;begin @(negedge clk);pp=1;@(negedge clk);pp=0;end endtask
initial begin
#31;rst=0;repeat(3)@(negedge clk);if(!busy || !reset_loader)$fatal(1,"startup gate");init=1;
active=0;job(0,0);finish_fg(0,0);job(1,1);if(busy)$fatal(1,"prefetch exposed LOADING");finish_bg(1);
job(2,1);repeat(4)@(negedge clk);
fork prev_button();job(3,0);join
finish_fg(3,0);job(2,1);wait(!reset_loader);@(negedge clk);lf=1;@(negedge clk);lf=0;
saved=starts;repeat(120)@(negedge clk);if(starts!=saved || all_failed || busy)$fatal(1,"prefetch failure did not stop retries quietly");
fork prev_button();job(2,0);join
finish_fg(2,0);active=1;repeat(4)@(negedge clk);if(valid!=15)$fatal(1,"cache not full");
for(n=0;n<9;n=n+1)begin
 expected=shown+2'd1;fork next_button();job(expected,0);join
 finish_fg(expected,1);repeat(4)@(negedge clk);
end
@(negedge clk);mp=1;@(negedge clk);mp=0;expected=shown+2'd1;job(expected,0);finish_fg(expected,1);
// Leaving ALBUM pauses auto advance even with all four slots cached.
@(negedge clk);active=0;saved=starts;repeat(1000)@(negedge clk);
if(starts!=saved || !auto_mode || d.hold_count!=0)$fatal(1,"HOME auto timer did not pause");
@(negedge clk);active=1;expected=shown+2'd1;job(expected,0);finish_fg(expected,1);
// Switching interval resets its timer but leaves all cached slots intact.
@(negedge clk);period=1;repeat(10)@(negedge clk);if(!auto_mode || valid!=15)$fatal(1,"period/cache state");
// Auto dwell must advance while a background job is still reading.
@(negedge clk);rst=1;valid=0;shown=0;repeat(3)@(negedge clk);rst=0;
job(0,0);finish_fg(0,0);job(1,1);wait(!reset_loader);
@(negedge clk);mp=1;@(negedge clk);mp=0;
saved=starts;wait(promote);#1;if(bg || !busy || selected!=1 || starts!=saved || reset_loader)$fatal(1,"same-target promotion restarted or stalled");finish_fg(1,0);
// Four failed foreground candidates must stop, preserving the original behavior.
@(negedge clk);rst=1;valid=0;shown=0;repeat(3)@(negedge clk);rst=0;
for(n=0;n<4;n=n+1)begin
 job(n,0);wait(!reset_loader);@(negedge clk);lf=1;@(negedge clk);lf=0;
end
repeat(5)@(negedge clk);if(!all_failed || !reset_loader)$fatal(1,"missing all-failed stop");
$display("PASS presentation pause, prefetch while HOME, cache controller initial load, background order/quiet UI, manual preemption, failed prefetch skip/retry, nine cached hits with zero loader releases, auto mode during background I/O, all-failed stop");$finish;
end
initial begin #300000;$fatal(1,"control timeout state=%d mask=%b selected=%d",d.state,valid,selected);end
endmodule
