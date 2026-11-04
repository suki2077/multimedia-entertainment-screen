`timescale 1ns/1ps
module tb_album20_store;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg gv=0,ldone=0,begin_job=0,bg=0,promote=0,req=0;reg [4:0] selected=0;reg [8:0] row=0;
 reg [20:0] ga=0;reg [127:0] gd=0;wire gr,pending,swapped,we,re,lwe,ack,ready,failed;
 wire [19:0] cache,tags;wire [3:0] valid;wire [4:0] displayed;wire [20:0] wa,ra;wire [31:0] wd,lw;
 wire [10:0] la;wire [8:0] te,to;wire ve,vo;
 reg [2:0] rv=0;reg [31:0] d0=0,d1=0,d2=0;reg [31:0] mem[0:1228799];
 frame_store_cached #(.MAX_IMAGES(20)) d(.clk(clk),.rst(rst),.init_done(1'b1),.refresh_busy(1'b0),
 .group_valid(gv),.group_ready(gr),.group_addr(ga),.group_data(gd),.load_done(ldone),.load_failed(1'b0),.begin_load(begin_job),.swap_allowed(1'b1),.prefetch(bg),.promote(promote),
 .frame_pending(pending),.image_index(selected),.cache_valid(cache),.swapped(swapped),.displayed(displayed),
 .wr_en(we),.wr_addr(wa),.wr_data(wd),.rd_en(re),.rd_addr(ra),.rd_valid(rv[2]),.rd_data(d2),
 .line_req_toggle(req),.line_req_row(row),.line_ack_toggle(ack),.line_we(lwe),.line_waddr(la),.line_wdata(lw),
 .tag_even(te),.tag_odd(to),.valid_even(ve),.valid_odd(vo),.ready(ready),.failed(failed),.photo_count(5'd20),.cache_tags(tags),.cache_slots_valid(valid));
 function [31:0] datum(input integer image,offset);datum=(image<<19)|offset;endfunction
 integer writes=0,reads=0,write_offset=0,fill_image_id=0,line_n=0,expect_image=0,expect_row=0,checks=0;
 reg monitor=0;
 always @(posedge clk)if(!rst)begin
  rv<={rv[1:0],re};d1<=d0;d2<=d1;
  if(re)begin if(ra>=1228800)$fatal(1,"photo read collided with video SDRAM");d0<=mem[ra];reads=reads+1;end
  if(we)begin
   if(wa>=1228800 || wa%307200!=write_offset || wd!==datum(fill_image_id,write_offset))$fatal(1,"write address/data id=%d offset=%d addr=%d data=%h",fill_image_id,write_offset,wa,wd);
   if(ready && wa/307200==d.display_slot)$fatal(1,"active photo overwritten");
   mem[wa]=wd;write_offset=write_offset+1;writes=writes+1;
  end
  if(lwe && monitor)begin
   if(la!==expect_row%2*1024+line_n || lw!==datum(expect_image,expect_row*640+line_n))$fatal(1,"line mismatch image=%d row=%d word=%d data=%h",expect_image,expect_row,line_n,lw);
   line_n=line_n+1;checks=checks+1;
  end
  if(failed)$fatal(1,"store failure");
 end
 task launch(input integer image,input background);begin
  @(negedge clk);selected=image;bg=background;ldone=0;begin_job=1;
  @(negedge clk);begin_job=0;repeat(4)@(negedge clk);
 end endtask
 task fill(input integer image,input integer groups);integer n;begin
  fill_image_id=image;write_offset=0;
  for(n=0;n<groups;n=n+1)begin
   @(negedge clk);ga=n*4;gd={datum(image,n*4+3),datum(image,n*4+2),datum(image,n*4+1),datum(image,n*4)};gv=1;
   @(posedge clk);while(!gr)@(posedge clk);
   @(negedge clk);gv=0;
  end
  if(groups==76800)begin ldone=1;wait(cache[image]);repeat(3)@(negedge clk);if(write_offset!=307200)$fatal(1,"frame word count");end
 end endtask
 task fetch(input integer r,input integer image);begin
  @(negedge clk);row=r;expect_row=r;expect_image=image;line_n=0;monitor=1;req=~req;
  wait(ack==req);@(negedge clk);monitor=0;
  if(line_n!=640 || displayed!=image || (r%2==0?te:to)!=r)$fatal(1,"line commit image=%d/%d words=%d",displayed,image,line_n);
 end endtask
 integer n,saved;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  launch(0,0);fill(0,76800);wait(ready);repeat(4)@(negedge clk);fetch(1,0);
  for(n=1;n<20;n=n+1)begin
   launch(n,0);
   fork
    fill(n,76800);
    begin repeat(300)@(negedge clk);fetch(128,n-1);end
   join
   wait(pending);fetch(0,n);fetch(239,n);fetch(479,n);
  end
  // Forward wrap is a cache miss; immediate reverse uses the retained slot.
  launch(0,0);fill(0,76800);wait(pending);fetch(0,0);
  saved=writes;if(!cache[19])$fatal(1,"previous neighbour evicted");launch(19,0);wait(pending);fetch(0,19);if(writes!=saved)$fatal(1,"cache hit wrote SDRAM");
  // Cancel a partially written background photo without touching displayed data.
  launch(7,1);fill(7,16);launch(18,0);wait(pending);fetch(0,18);if(cache[7])$fatal(1,"cancelled partial frame marked valid");
  // Promote the same background job, retaining all already written words.
  launch(9,1);
  fork
   fill(9,76800);
   begin repeat(600)@(negedge clk);promote=1;@(negedge clk);promote=0;fetch(128,18);end
  join
  wait(pending);fetch(0,9);
  $display("PASS all 20 logical photos, %0d exact SDRAM writes, %0d exact line pixels, 4-slot eviction, simultaneous line reads, 20-to-1 wrap, reverse hit, partial cancellation and background promotion; no active/video storage overwrite",writes,checks);$finish;
 end
 initial begin #2000000000;$fatal(1,"store timeout state=%d selected=%d writes=%d",d.state,selected,writes);end
endmodule
