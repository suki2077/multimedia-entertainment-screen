`timescale 1ns/1ps
module tb_scale_math;
 reg clk=0;always #5 clk=~clk;reg rst=1,ds=0,ls=0;
 reg[23:0] n,a,b;reg[12:0] d;reg[7:0] f;
 wire[23:0] q,rgb;wire[12:0] r;wire busy,dd,ld;
 scale_divider div(clk,rst,ds,n,d,q,r,busy,dd);
 scale_lerp lerp(clk,rst,ls,a,b,f,rgb,ld);
 integer i,k,expected;reg[23:0] e;
 initial begin
  n=0;d=1;a=0;b=0;f=0;repeat(4)@(negedge clk);rst=0;
  for(i=0;i<1500;i=i+1)begin
   n=$random;d=($urandom%4096)+1;
   if(i==0)begin n=24'hffffff;d=4096;end
   ds=1;@(negedge clk);ds=0;wait(dd);@(negedge clk);
   if(q!==n/d||r!==n%d)$fatal(1,"divide %d / %d q=%d r=%d",n,d,q,r);
  end
  for(i=0;i<8192;i=i+1)begin
   a=$random;b=$random;f=i;
   if(i<256)begin a=24'h00ff00;b=24'hff00ff;end
   for(k=0;k<3;k=k+1)begin expected=(a[k*8+:8]*(256-f)+b[k*8+:8]*f+128)/256;e[k*8+:8]=expected;end
   ls=1;@(negedge clk);ls=0;wait(ld);@(negedge clk);
   if(rgb!==e)$fatal(1,"lerp %h %h f=%d got %h expected %h",a,b,f,rgb,e);
  end
  $display("PASS SCALE MATH: 1500 divisions, 8192 RGB interpolation vectors");$finish;
 end
endmodule
