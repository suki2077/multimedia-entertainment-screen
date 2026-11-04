`timescale 1ns/1ps
module tb_album20_tagged;
 reg clk=0,rst=1,np=0,swap=0;always #5 clk=~clk;
 reg [4:0] shown=0;reg [3:0] valid=0;wire [4:0] selected;wire reset_loader,begin_job;
 cache_album_control #(.MAX_IMAGES(20),.TAGGED(1)) d(.clk(clk),.rst(rst),.init_done(1'b1),.next_press(np),.prev_press(1'b0),.mode_press(1'b0),.period_long(1'b0),
 .presentation_active(1'b0),.swapped(swap),.load_failed(1'b0),.fatal_error(1'b0),.displayed(shown),.cache_valid(20'd0),.selected(selected),.loader_reset(reset_loader),.begin_load(begin_job),
 .scan_done(1'b0),.scan_count(5'd20),.cache_tags({5'd19,5'd12,5'd7,5'd0}),.cache_slots_valid(valid));
 integer mask,n,j,wanted_hit;
 initial begin
  for(mask=0;mask<16;mask=mask+1)for(n=0;n<20;n=n+1)begin
   rst=1;np=0;swap=0;shown=0;valid=mask;repeat(4)@(negedge clk);rst=0;
   wait(begin_job);repeat(72)@(negedge clk);
   shown=n==0?19:n-1;swap=1;@(negedge clk);swap=0;np=1;
   @(negedge clk);np=0;
   if(!begin_job || selected!=n)$fatal(1,"tagged request selection %d/%d",selected,n);
   wanted_hit=(n==0 && (mask&1)!=0)||(n==7 && (mask&2)!=0)||(n==12 && (mask&4)!=0)||(n==19 && (mask&8)!=0);
   repeat(72)@(negedge clk);
   if(reset_loader!==1'(wanted_hit))$fatal(1,"tagged loader gating n=%d mask=%h reset=%b hit=%d",n,mask,reset_loader,wanted_hit);
  end
  $display("PASS tagged-cache control: 20 logical indices x16 valid-slot masks, exact hit/miss loader gating, 5-bit indices and wrap");$finish;
 end
 initial begin #2000000;$fatal(1,"tagged timeout");end
endmodule
