`timescale 1ns/1ps
module tb_dynamic_title_preview;
 reg pc=0,mc=0,rst=1;always #20 pc=~pc;always #7 mc=~mc;
 reg vs=1,opened=1,kind=1;reg [2:0] cursor=0;reg tw=0,tb=0,tc=0;reg [11:0] ta=0;reg [7:0] td=0;
 reg [9:0] x=1023,y=1023;wire [23:0] rgb;reg [7:0] expected[0:4095];
 shell_overlay #(.LIBRARY(1),.DYNAMIC_TITLES(1),.MAX_IMAGES(20)) d(.clk(pc),.rst(rst),.page(2'd1),.home_selected(2'd0),.settings_selected(2'd0),
 .brightness(2'd3),.sound_enable(1'b1),.period_long(1'b0),.playing(1'b1),.photo_ready(1'b1),.image_index(5'd0),.image_count(5'd20),.meter_levels(32'd0),.volume(3'd4),
 .x(x),.y(y),.rgb_in(24'h19303d),.rgb_out(rgb),.catalog_clk(mc),.catalog_entry(1'b0),.catalog_type(kind),.catalog_index(3'd0),.catalog_name(88'd0),
 .library_open(opened),.library_type(kind),.library_ready(1'b1),.library_cursor(cursor),.library_count(4'd8),.vs(vs),
 .title_write(tw),.title_addr(ta),.title_data(td),.title_begin(tb),.title_commit(tc));
 task frame;begin @(negedge pc);vs=0;repeat(3)@(negedge pc);vs=1;repeat(3)@(negedge pc);end endtask
 task write_byte(input integer addr,input [7:0] data);begin @(negedge mc);tw=1;ta=addr;td=data;@(negedge mc);tw=0;end endtask
 integer fd,i,row,yy,n,xx,idx,col,code,wordbits,bit_on,checks=0,maxoff=0,previous,saw_wrap=0;
 reg [23:0] ink;
 task check_line(input integer line_y);begin
  for(n=0;n<643;n=n+1)begin
   @(negedge pc);x=n<640?n:0;y=line_y;@(posedge pc);#1;
   if(n>=2)begin
    xx=n-2;idx={cursor[2],2'd0}+(line_y-128)/64;
    col=(xx-144+(idx==cursor?d.scroll_offset:0))/16;
    if(xx>=144 && xx<560 && col>=0 && col<expected[2048+idx*64])begin
     code=expected[2049+idx*64+col];
     if(code>=128)begin
      wordbits={expected[(code-128)*32+((line_y-152)%64)*2+1],expected[(code-128)*32+((line_y-152)%64)*2]};
      bit_on=(wordbits>>(15-((xx-144+(idx==cursor?d.scroll_offset:0))%16)))&1;
      ink=idx==cursor?24'heaf1f7:24'h93a8bb;
      if(^rgb===1'bx || ((rgb===ink)!==1'(bit_on)))$fatal(1,"dynamic glyph stream x%d y%d code%h bit%d RGB%h col%d word%h xq%d",xx,line_y,code,bit_on,rgb,d.dynamic_col_qq,d.DYNAMIC.word_qq,d.xq);
      checks=checks+1;
     end
    end
   end
  end
 end endtask
 initial begin
  $readmemh("sim/fixtures/dynamic_titles/expected1.hex",expected);
  repeat(5)@(negedge pc);rst=0;
  @(negedge mc);tb=1;@(negedge mc);tb=0;
  for(i=0;i<2048;i=i+1)write_byte(i,expected[i]);
  for(i=2048;i<2560;i=i+1)write_byte(i,expected[i]);
  @(negedge mc);tc=1;@(negedge mc);tc=0;repeat(12)@(negedge pc);frame();frame();
  fd=$fopen("preview/dynamic_titles_video.ppm","w");$fwrite(fd,"P3\n640 480\n255\n");
  for(n=0;n<307202;n=n+1)begin
   @(negedge pc);x=n<307200?n%640:0;y=n<307200?n/640:0;@(posedge pc);#1;
   if(n>=2)begin if(^rgb===1'bx)$fatal(1,"unknown title preview pixel");$fwrite(fd,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);end
  end
  $fclose(fd);$display("PASS actual RTL dynamic Chinese filename menu, full streamed frame, all pixels known");$finish;
 end
 initial begin #30000000;$fatal(1,"dynamic UI timeout");end
endmodule
