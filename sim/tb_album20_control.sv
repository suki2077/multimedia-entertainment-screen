`timescale 1ns/1ps
module tb_album20_control;
 reg clk=0,rst=1,np=0,pp=0,mp=0,swap=0,sdone=0;always #5 clk=~clk;
 reg [4:0] shown=0,scount=20;reg [19:0] valid=0;wire [4:0] selected,count;
 wire busy,started,reset_loader,begin_job,auto_mode,all_failed,bg,promote,scan;
 cache_album_control #(.MAX_IMAGES(20),.SCAN(1),.TICK_CYCLES(2),.HOLD_TICKS(50),.HOLD_TICKS_LONG(100)) d(
 .clk(clk),.rst(rst),.init_done(1'b1),.next_press(np),.prev_press(pp),.mode_press(mp),.period_long(1'b0),.presentation_active(1'b1),
 .swapped(swap),.load_failed(1'b0),.fatal_error(1'b0),.displayed(shown),.cache_valid(valid),.selected(selected),.busy(busy),.started(started),
 .loader_reset(reset_loader),.begin_load(begin_job),.auto_mode(auto_mode),.all_failed(all_failed),.prefetch(bg),.promote(promote),
 .scan_done(sdone),.scan_count(scount),.scan_only(scan),.photo_count(count));
 integer testno,n,total,wanted_value;
 task wait_job(input integer want);begin
  wait(begin_job);#1;if(selected!=want || bg)$fatal(1,"job %d/%d bg=%b",selected,want,bg);
  @(negedge clk);wait(!begin_job);repeat(68)@(negedge clk);
  shown=want;swap=1;@(negedge clk);swap=0;repeat(4)@(negedge clk);
 end endtask
 initial begin
  for(testno=0;testno<4;testno=testno+1)begin
   total=testno==0?0:testno==1?1:testno==2?4:20;
   rst=1;sdone=0;valid=0;shown=0;scount=total;repeat(4)@(negedge clk);rst=0;
   wait(scan && !reset_loader);repeat(4)@(negedge clk);
   if(!busy || begin_job)$fatal(1,"scan startup gating");
   valid=(1<<total)-1;sdone=1;@(negedge clk);sdone=0;
   if(total==0)begin repeat(8)@(negedge clk);if(!all_failed || !reset_loader || count!=0)$fatal(1,"empty catalog");end
   else begin
    wait_job(0);if(count!=total)$fatal(1,"total count");
    for(n=0;n<total+2;n=n+1)begin
     wanted_value=shown==0?total-1:shown-1;
     @(negedge clk);pp=1;@(negedge clk);pp=0;wait_job(wanted_value);
    end
    for(n=0;n<total+2;n=n+1)begin
     wanted_value=shown+1==total?0:shown+1;
     @(negedge clk);np=1;@(negedge clk);np=0;wait_job(wanted_value);
    end
    mp=1;@(negedge clk);mp=0;wanted_value=shown+1==total?0:shown+1;wait_job(wanted_value);
   end
  end
  $display("PASS 0/1/4/20 photo catalog handoff, startup gating, forward/backward wrap across every index, cached presentation, automatic playback and empty stop");$finish;
 end
 initial begin #5000000;$fatal(1,"control timeout state=%d selected=%d",d.state,selected);end
endmodule
