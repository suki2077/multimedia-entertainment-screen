`timescale 1ns/1ps
module tb_shared_line;
 reg wc=0,rc=0,we=0,mode=0;always #7 wc=~wc;always #20 rc=~rc;
 reg [10:0] wa=0,ra=0;reg [31:0] wd=0;wire [23:0] q;
 line_buffer d(.wclk(wc),.we(we),.waddr(wa),.wdata(wd),.wvideo(mode),.rclk(rc),.raddr(ra),.rvideo(mode),.q(q));
 function [23:0] rgb;input integer b,n;begin rgb=24'(b*1943+n*731+43);end endfunction
 function [15:0] color;input integer b,n;begin color=16'(b*1947+n*311+913);end endfunction
 function [23:0] expand;input [15:0] c;begin expand={c[15:11],c[15:13],c[10:5],c[10:9],c[4:0],c[4:2]};end endfunction
 integer pass,b,n;reg [23:0] expected;
 initial begin
  for(pass=0;pass<3;pass=pass+1)begin
   mode=pass==1;
   for(b=0;b<2;b=b+1)begin
    for(n=0;n<(mode?200:640);n=n+1)begin
     @(negedge wc);we=1;wa=b*1024+n;wd=mode?{color(b,n*2+1),color(b,n*2)}:{8'd0,rgb(b,n)};
    end
    @(negedge wc);we=0;
   end
   for(b=0;b<2;b=b+1)for(n=0;n<(mode?400:640);n=n+1)begin
    @(negedge rc);ra=b*1024+n;expected=mode?expand(color(b,n)):rgb(b,n);
    @(posedge rc);#1;if(q!==expected)$fatal(1,"shared line mode=%d bank=%d pixel=%d got=%h",mode,b,n,q);
   end
  end
  $display("PASS shared RAM: RGB888 album -> packed RGB565 video -> RGB888 album, both banks, all pixels and padded tails, one-cycle read latency");$finish;
 end
endmodule
