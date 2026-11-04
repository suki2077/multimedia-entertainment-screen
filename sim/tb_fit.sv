`timescale 1ns/1ps
module tb_fit;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,start=0;reg[12:0] width,height;reg td;
 wire ready,gv,done,failed;wire[20:0] ga;wire[127:0] gd;
 integer w,h,top,n=0,cycles=0,groups=0,fd;reg[1023:0] outname;
 wire valid=n<w*h && cycles%5!=1;
 wire gr=cycles%11!=3 && cycles%11!=4;
 function[23:0] color(input integer x,y);
  begin color={8'((x*17+y*3)^((x/7)*51)),8'((y*19+x*5)^((y/9)*31)),8'(x*11+y*13)};end
 endfunction
 wire[23:0] raw=color(n%w,n/w);
 bmp_fit_scaler dut(clk,rst,start,width,height,td,valid,raw,ready,gv,gr,ga,gd,done,failed);
 reg held=0;reg[148:0] held_group;
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;
  if(valid&&ready)n<=n+1;
  if(held && {ga,gd}!==held_group)$fatal(1,"group changed while stalled");
  held<=gv&&!gr;held_group<={ga,gd};
  if(gv&&gr)begin $fdisplay(fd,"%06x %032x",ga,gd);groups<=groups+1;end
  if(failed)$fatal(1,"scaler failed state %d sy %d y %d",dut.state,dut.sy,dut.ycoord);
  if(done && n==w*h)begin
   if(groups!=76800)$fatal(1,"wrong group count %d",groups);
   $display("PASS FIT %0dx%0d top=%0d cycles=%0d groups=%0d",w,h,top,cycles,groups);$fclose(fd);$finish;
  end
  if(cycles>20000000)$fatal(1,"timeout state=%d sx=%d sy=%d ox=%d oy=%d dx=%d curr=%d need=%d",dut.state,dut.sx,dut.sy,dut.ox,dut.oy,dut.dx,dut.curr_x,dut.need_x);
 end
 initial begin
  if(!$value$plusargs("W=%d",w))w=640;if(!$value$plusargs("H=%d",h))h=480;
  if(!$value$plusargs("TOP=%d",top))top=1;
  if(!$value$plusargs("OUT=%s",outname))outname="build/fit.txt";
  width=w;height=h;td=top;fd=$fopen(outname,"w");
  repeat(4)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
 end
endmodule
