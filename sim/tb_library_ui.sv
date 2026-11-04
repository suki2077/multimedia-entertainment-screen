`timescale 1ns/1ps
module tb_library_ui;
 reg clk=0,mc=0,rst=1,vs=1,entry=0,typ=0,opened=0,ready=1;reg [2:0] idx=0,cursor=0;reg [3:0] count=8;
 always #20 clk=~clk;always #7 mc=~mc;
 reg [87:0] name=0;reg [9:0] x=0,y=0;wire [23:0] rgb;integer j,i,fd,page_no,t,c;reg [7:0] expect_char;reg [87:0] filename;reg [7:0] original_text[0:383];
 shell_overlay #(.LIBRARY(1)) d(.clk(clk),.rst(rst),.page(2'd1),.home_selected(2'd0),.settings_selected(2'd0),
  .brightness(2'd3),.sound_enable(1'b1),.period_long(1'b0),.playing(1'b1),.photo_ready(1'b1),.image_index(2'd0),.meter_levels(32'd0),
  .x(x),.y(y),.rgb_in(24'h123456),.rgb_out(rgb),.volume(3'd4),
  .catalog_clk(mc),.catalog_entry(entry),.catalog_type(typ),.catalog_index(idx),.catalog_name(name),
  .library_open(opened),.library_type(typ),.library_ready(ready),.library_cursor(cursor),.library_count(count),.vs(vs));
 task frame_commit;begin
  repeat(15)@(negedge clk);vs=0;repeat(8)@(negedge clk);vs=1;repeat(8)@(negedge clk);
 end endtask
 task render(input integer n);begin
  case(n)0:fd=$fopen("preview/library_music.ppm","wb");1:fd=$fopen("preview/library_video.ppm","wb");2:fd=$fopen("preview/library_empty.ppm","wb");4:fd=$fopen("preview/library_chinese.ppm","wb");default:fd=$fopen("preview/library_scanning.ppm","wb");endcase
  $fwrite(fd,"P6\n640 480\n255\n");
  for(j=0;j<480;j=j+1)for(i=0;i<640;i=i+1)begin
   @(negedge clk);x=i;y=j;repeat(4)@(posedge clk);#1;$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  end
  $fclose(fd);
 end endtask
 function [63:0] demo_base;input integer v,n;begin
  if(v==0)case(n)
   0:demo_base="SUMMER  ";1:demo_base="SUNRISE ";2:demo_base="OCEAN   ";3:demo_base="FOREST  ";
   4:demo_base="STARS   ";5:demo_base="NIGHT   ";6:demo_base="PIANO   ";default:demo_base="RAIN    ";endcase
  else case(n)
   0:demo_base="TRAVEL  ";1:demo_base="OCEAN   ";2:demo_base="NATURE  ";3:demo_base="CITY    ";
   4:demo_base="SUNSET  ";5:demo_base="MOUNTAIN";6:demo_base="CLOUDS  ";default:demo_base="STARS   ";endcase
 end endfunction
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(i=0;i<384;i=i+1)original_text[i]=d.char_rom[i];
  for(t=0;t<2;t=t+1)begin typ=t;
   for(i=0;i<8;i=i+1)begin
    @(negedge mc);idx=i;name={8'h41+8'(i),56'h42434445464748,t?24'h534156:24'h574156};entry=1;
    @(negedge mc);entry=0;repeat(32)@(negedge mc);
   end
  end
  opened=1;
  for(t=0;t<2;t=t+1)begin typ=t;
   for(page_no=0;page_no<2;page_no=page_no+1)begin
    cursor=page_no*4+1;frame_commit();
    if(!d.list_open || d.list_cursor!==cursor || d.list_type!==typ)$fatal(1,"CDC state");
    for(j=0;j<4;j=j+1)for(c=0;c<12;c=c+1)begin
     @(negedge clk);x=144+c*8;y=152+j*64;repeat(4)@(negedge clk);
     filename={8'h41+8'(j+page_no*4),56'h42434445464748,t?24'h534156:24'h574156};
     expect_char=c==8?8'h2e:c<8?filename>>(80-c*8):filename>>(16-(c-9)*8);
     if(!d.file_q || d.filename_char!==expect_char || d.small_glyph!==d.library_glyph(expect_char))$fatal(1,"name RAM/font pipeline type=%0d page=%0d row=%0d c=%0d got=%h expected=%h",t,page_no,j,c,d.filename_char,expect_char);
    end
   end
   for(i=0;i<8;i=i+1)begin
    @(negedge mc);idx=i;name={demo_base(t,i),t?24'h534156:24'h574156};entry=1;
    @(negedge mc);entry=0;repeat(32)@(negedge mc);
   end
   cursor=t?5:0;frame_commit();render(t);
  end
 
  // Chinese aliases never change the directory names or video labels.
  typ=0;count=3;
  for(i=0;i<3;i=i+1)begin
   @(negedge mc);idx=i;
   case(i)0:name={8'hce,56'h4142437e312020,24'h574156};1:name="ZAIJIAN WAV";2:name="WEIYI   WAV";endcase
   entry=1;@(negedge mc);entry=0;repeat(32)@(negedge mc);
  end
  cursor=1;frame_commit();
  if(d.char_rom[384]!==1 || d.char_rom[392]!==2 || d.char_rom[400]!==1)$fatal(1,"alias matching");
  for(t=0;t<3;t=t+1)for(j=0;j<16;j=j+1)begin
   @(negedge clk);x=120;y=152+t*64+j;repeat(4)@(negedge clk);
   x=128;repeat(4)@(negedge clk);
   for(c=0;c<128;c=c+1)begin
   @(negedge clk);x=144+c;y=152+t*64+j;repeat(4)@(negedge clk);
   if(!d.title_active_qq || d.coverage!==(d.title_rom[2*((t==1?128:0)+c)+j/8]>>(14-(j%8)*2)&3))
    $fatal(1,"Chinese pixel pipeline row=%0d x=%0d y=%0d got=%h",t,c,j,d.coverage);
  end
  end
  count=2;frame_commit();render(4);
  typ=1;frame_commit();@(negedge clk);x=160;y=152;repeat(4)@(negedge clk);
  if(d.title_active_qq)$fatal(1,"music alias leaked into video library");
  typ=0;count=0;frame_commit();render(2);ready=0;frame_commit();render(3);
  opened=0;frame_commit();repeat(4)@(negedge clk);if(rgb!==24'h123456)$fatal(1,"modal close passthrough");
  for(i=0;i<384;i=i+1)if(d.char_rom[i]!==original_text[i])$fatal(1,"catalog overwrote static UI text %0d",i);
  $display("PASS Chinese aliases and 6144 exact coverage pixels; library name RAM, both media types, 8 indices, 12 ASCII columns, page flip, CDC, empty/scanning views and passthrough");$finish;
 end
 initial begin #1000000000;$fatal(1,"UI timeout");end
endmodule
