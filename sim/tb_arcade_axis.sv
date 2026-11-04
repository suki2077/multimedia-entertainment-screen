`timescale 1ns/1ps
module tb_arcade_axis;
reg clk=0,rst=1;always #5 clk=~clk;
reg [9:0] x=1023,y=1023;reg [1:0] page=2;reg raw_de=0,raw_vs=1;
reg pd=0,pv=1,d0=0,d1=0,v0=1,v1=1;reg d2=0,v2=1;reg [3:0] visible=0;
reg[23:0] s0=0,s1=0,s2=0,s3=0;wire[23:0] game_rgb,rgb,data;wire user,valid,last;
function[23:0] pattern(input integer xx,yy);begin pattern={8'(xx),8'(yy),8'(xx^yy)};end endfunction
always @(posedge clk)begin
pd<=raw_de;pv<=raw_vs;d0<=pd;d1<=d0;d2<=d1;v0<=pv;v1<=v0;v2<=v1;
visible<={visible[2:0],page==2};s0<=pattern(x,y);s1<=s0;s2<=s1;s3<=s2;
end
arcade_renderer d(clk,rst,x,y,1'b1,1'b0,3'd1,2'd2,2'd2,16'h0140,32'hffffffff,
10'd276,10'd320,10'd316,10'd312,10'd308,9'd334,9'd338,9'd342,9'd346,10'd0,9'd0,4'd0,game_rgb,1'b0,1'b0,1'b0);
assign rgb=visible[3]?game_rgb:s3;
rgb_to_axis a(clk,rst,v2,d2,rgb,user,valid,last,data);
integer rows[0:9];integer count=0,us=0,ls=0,ex,ey,m,j,xx;
reg [23:0] bg;
always @(posedge clk)begin #1;if(!rst && valid)begin
ex=count%640;ey=rows[count/640];bg={8'(9+((ey>>7)&3)),8'(16+((ey>>7)&3)),8'(28+((ey>>6)&7))};
if(page==1 && data!==pattern(ex,ey))$fatal(1,"photo mux alignment x%0d y%0d",ex,ey);
if(page==2)begin
if(ex==639 && data!==bg)$fatal(1,"game last pixel alignment %d,%d %h expected %h",ex,ey,data,bg);
if(ex==90 && ey==138 && data!==24'hef9d8c)$fatal(1,"brick alignment");
if(ex==320 && ey==334 && data!==24'heaf1f7)$fatal(1,"ball alignment");
if(ex==300 && ey==416 && data!==24'h66dfbd)$fatal(1,"paddle alignment");
end
if(last!==(ex==639) || user!==(count==0))$fatal(1,"AXIS SOF/LAST");
if(last)ls=ls+1;if(user)us=us+1;count=count+1;
end end
initial begin
rows[0]=0;rows[1]=70;rows[2]=86;rows[3]=128;rows[4]=138;rows[5]=334;rows[6]=414;rows[7]=416;rows[8]=458;rows[9]=479;
repeat(4)@(negedge clk);rst=0;
for(m=0;m<2;m=m+1)begin
page=m==0?2:1;count=0;us=0;ls=0;raw_vs=0;repeat(8)@(negedge clk);raw_vs=1;repeat(8)@(negedge clk);
for(j=0;j<10;j=j+1)for(xx=0;xx<800;xx=xx+1)begin x=xx;y=rows[j];raw_de=xx<640;@(negedge clk);end
raw_de=0;repeat(8)@(negedge clk);if(count!=6400 || us!=1 || ls!=10)$fatal(1,"pixel counts");
end
$display("PASS game/media pixel mux, 20 full-width rows, exact ball/paddle/brick positions, all photo pixels, SOF and LAST aligned");$finish;
end
endmodule
