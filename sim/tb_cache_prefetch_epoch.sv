`timescale 1ns/1ps
module tb_cache_prefetch_epoch;
 reg clk=0,rst=1,np=0,swap=0,failed=0;always #5 clk=~clk;
 reg[4:0]displayed=0;reg[19:0]tags=0;reg[3:0]valid=0;
 wire[4:0]selected;wire begin_job,bg,loader_reset;integer starts=0,saved;
 cache_album_control #(.MAX_IMAGES(20),.TAGGED(1)) d(.clk(clk),.rst(rst),.init_done(1'b1),.next_press(np),.prev_press(1'b0),.mode_press(1'b0),.period_long(1'b0),
 .presentation_active(1'b0),.swapped(swap),.load_failed(failed),.fatal_error(1'b0),.displayed(displayed),.cache_valid(20'd0),.selected(selected),.loader_reset(loader_reset),.begin_load(begin_job),.prefetch(bg),
 .scan_done(1'b0),.scan_count(5'd20),.cache_tags(tags),.cache_slots_valid(valid));
 always @(posedge clk)if(begin_job)starts=starts+1;
 task job;input[4:0]index;input background;begin
  wait(begin_job);#1;if(selected!==index || bg!==background)$fatal(1,"prefetch target %d/%b expected %d/%b",selected,bg,index,background);
  @(negedge clk);wait(!begin_job);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;job(0,0);wait(!loader_reset);
  @(negedge clk);tags[4:0]=0;valid[0]=1;swap=1;@(negedge clk);swap=0;
  job(1,1);wait(!loader_reset);@(negedge clk);tags[9:5]=1;valid[1]=1;
  job(2,1);wait(!loader_reset);@(negedge clk);failed=1;@(negedge clk);failed=0;
  job(19,1);wait(!loader_reset);@(negedge clk);tags[19:15]=19;valid[3]=1;
  saved=starts;repeat(120)@(negedge clk);
  if(starts!=saved)$fatal(1,"failed candidate retried from stale snapshot");
  np=1;@(negedge clk);np=0;job(1,0);
  repeat(72)begin @(negedge clk);if(!loader_reset)$fatal(1,"cached foreground released loader");end
  displayed=1;swap=1;@(negedge clk);swap=0;
  job(2,1);
  $display("PASS tagged prefetch commit/failure snapshots, no stale retry, cached foreground, displayed-index advance and explicit retry after manual navigation");$finish;
 end
 initial begin #100000;$fatal(1,"cache snapshot timeout state=%d target=%d",d.state,selected);end
endmodule
