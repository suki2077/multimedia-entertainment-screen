`timescale 1ns/1ps
module tb_line_smooth;
 reg wc=0,rc=0,we=0,mode=0;always #7 wc=~wc;always #20 rc=~rc;
 reg [10:0] wa=0,ra=0;reg [31:0] wd=0;reg [2:0] frac=0;wire [23:0] q;
 line_buffer #(.SMOOTH_VIDEO(1)) d(wc,we,wa,wd,mode,rc,ra,mode,q,frac);
 function [23:0] photo;input integer b,n;begin photo=24'(b*1943+n*731+43);end endfunction
 function [15:0] color;input integer b,n;begin color=16'(b*1947+n*311+913);end endfunction
 function [23:0] expand;input [15:0] c;begin expand={c[15:11],c[15:13],c[10:5],c[10:9],c[4:0],c[4:2]};end endfunction
 integer pass,b,n,f,c,a,z,nextn;reg [23:0] expected,left_rgb,right_rgb;
 always @(posedge wc)if(mode && d.we_q && d.valid_wq && d.video_wq && !d.first_q)
  if(d.video_previous_addr!==d.wa_q-9'd1)$fatal(1,"previous-address equivalence");
 initial begin
  repeat(5)@(negedge wc);
  for(pass=0;pass<3;pass=pass+1)begin
   mode=pass==1;
   // Back-to-back banks deliberately exercise last-pair flush + next row's first pair.
   for(b=0;b<2;b=b+1)for(n=0;n<(mode?240:640);n=n+1)begin
    if(mode && n%7==3 && n!=239)begin @(negedge wc);we=0;repeat(2)@(negedge wc);end
    @(negedge wc);we=1;wa=b*1024+n;wd=mode?{color(b,n*2+1),color(b,n*2)}:{8'd0,photo(b,n)};
   end
   @(negedge wc);we=0;repeat(5)@(negedge wc);
   for(b=0;b<2;b=b+1)for(n=0;n<(mode?480:640);n=n+1)for(f=0;f<(mode?8:1);f=f+1)begin
    @(negedge rc);ra=b*1024+n;frac=f;expected=photo(b,n);
    if(mode)begin
     nextn=n==479?479:n+1;left_rgb=expand(color(b,n));right_rgb=expand(color(b,nextn));
     for(c=0;c<24;c=c+8)begin a=(left_rgb>>c)&255;z=(right_rgb>>c)&255;expected[c+:8]=(a*(8-f)+z*f+4)/8;end
    end
    @(posedge rc);#1;if(q!==expected)$fatal(1,"line lerp mode=%d bank=%d pixel=%d f=%d got=%h expected=%h",mode,b,n,f,q,expected);
   end
  end
  // Exhaustive channel mixer reference, including negative slopes and saturated endpoints.
  for(a=0;a<256;a=a+1)for(z=0;z<256;z=z+1)for(f=0;f<8;f=f+1)
   if(d.lerp(a,z,f)!==8'((a*(8-f)+z*f+4)/8))$fatal(1,"mixer rounding");
  $display("PASS video neighbour reads: both banks, even/odd pair crossings, clamped tail, all 8 phases, photo/video/photo, all 524288 channel blends and one-cycle alignment");$finish;
 end
endmodule
