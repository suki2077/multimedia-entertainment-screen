`timescale 1ns/1ps
module tb_alignment;
reg clk=0,rst=1;always #5 clk=~clk;
reg[1:0] page=1;reg[9:0] x=0,y=0;
reg delay2_de=0,delay2_vs=1;
reg raw_de=0,raw_vs=1,parent_de=0,parent_vs=1,delayed_de=0,delayed_vs=1;
reg[23:0] raw_pixel=0,incoming=0;wire[23:0] rgb,data;wire user,valid,last;
always @(posedge clk)begin
 incoming<=raw_pixel;parent_de<=raw_de;parent_vs<=raw_vs;
 if(rst)begin delayed_de<=0;delayed_vs<=1;delay2_de<=0;delay2_vs<=1;end else begin delayed_de<=parent_de;delayed_vs<=parent_vs;delay2_de<=delayed_de;delay2_vs<=delayed_vs;end
end
shell_overlay d(clk,rst,page,2'd0,2'd0,2'd3,1'b1,1'b0,1'b1,1'b1,2'd0,32'd0,x,y,incoming,rgb,3'd4,1'b0,1'b0,1'b0,3'd0,88'd0,1'b0,1'b0,1'b0,3'd0,4'd0,1'b1,5'd4,1'b0);
rgb_to_axis a(clk,rst,delay2_vs,delay2_de,rgb,user,valid,last,data);
function[23:0] pixel;input integer xx,yy;begin pixel={8'(xx),8'(yy),8'(xx^yy)};end endfunction
integer count=0,users=0,lasts=0,mode,xx,yy,ex,ey;
always @(posedge clk)begin
 #1;
 if(!rst && valid)begin
  ex=count%640;ey=120+count/640;
  if((page==1 || (ex>=50 && ex<375)) && data!==pixel(ex,ey))$fatal(1,"RGB/DE misalignment page %d x %d y %d got %h expected %h",page,ex,ey,data,pixel(ex,ey));
  if(last!==(ex==639))$fatal(1,"LAST pixel %d",ex);
  if(user!==(count==0))$fatal(1,"SOF pixel %d",count);
  if(user)users=users+1;if(last)lasts=lasts+1;count=count+1;
 end
end
initial begin
repeat(3)@(negedge clk);rst=0;
for(mode=0;mode<2;mode=mode+1)begin
 page=mode==0?1:0;count=0;users=0;lasts=0;
 raw_de=0;raw_vs=0;repeat(6)@(negedge clk);raw_vs=1;repeat(6)@(negedge clk);
 for(yy=120;yy<124;yy=yy+1)begin
  for(xx=0;xx<800;xx=xx+1)begin
   x=xx;y=yy;raw_de=xx<640;raw_pixel=pixel(xx,yy);@(negedge clk);
  end
 end
 raw_de=0;repeat(8)@(negedge clk);
 if(count!=2560 || users!=1 || lasts!=4)$fatal(1,"video counts %d %d %d",count,users,lasts);
end
$display("PASS streamed RGB/DE alignment through desktop pipeline and RGB-to-AXIS: two modes, eight 640-pixel lines, exact photo pixels, SOF and LAST at correct pixels");$finish;
end
endmodule
