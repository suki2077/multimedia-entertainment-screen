`timescale 1ns/1ps
module tb_transition;
reg clk=0,rst=1;always #5 clk=~clk;
reg[4:0] lev=16;reg[1:0] mode=0;reg[23:0] pixel=0;reg[9:0] x=0,y=0;reg hi=0,vi=1,di=1;
wire[23:0] rgb;wire ho,vo,deo;wire[9:0] xo,yo;
fade_pipe p(.clk(clk),.rst(rst),.level(lev),.mode(mode),.rgb_in(pixel),.hs_in(hi),.vs_in(vi),.de_in(di),.x_in(x),.y_in(y),.rgb_out(rgb),.hs_out(ho),.vs_out(vo),.de_out(deo),.x_out(xo),.y_out(yo));
reg vs=1,pending=0,ready=1;reg[1:0] request=1;wire[1:0] active;wire[4:0] fade;wire swap;
fade_control c(clk,rst,vs,pending,ready,fade,swap,request,active);
reg cv=1,vm=0,toggle=0;reg[1:0] cmd=0;wire[1:0] brightness,effect;wire sound,period;wire[2:0] volume;
media_controls #(.TRANSITIONS(1),.DEBOUNCE_CYCLES(3)) m(clk,rst,4'd7,cv,vm,toggle,cmd,brightness,sound,period,volume,effect,);
reg np=0,pp=0,ok=0,home=0;wire[2:0] page;wire[1:0] focus,command;wire stoggle;
shell_control #(.TRANSITIONS(1)) shell(.clk(clk),.rst(rst),.next_press(np),.prev_press(pp),.confirm_short(ok),.home_long(home),.page(page),.settings_selected(focus),.setting_command(command),.setting_toggle(stoggle));
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame;begin vs=0;ticks(2);vs=1;ticks(4);end endtask
task setting_frame;begin cv=0;ticks(2);cv=1;ticks(4);end endtask
task adjust(input integer command);begin cmd=command;toggle=~toggle;ticks(10);end endtask
integer n,k,i,j,rv,gv,bv;reg[23:0] expected;
task sample(input integer xx,yy);begin
@(negedge clk);x=xx;y=yy;pixel={8'(xx+yy),8'(xx*3-yy),8'(xx^yy)};hi=xx[0];vi=yy[0];di=xx%7!=0;
rv=pixel[23:16];gv=pixel[15:8];bv=pixel[7:0];expected={8'(rv*lev/16),8'(gv*lev/16),8'(bv*lev/16)};
if(mode==1)expected=xx<lev*40 ? pixel : 0;
if(mode==2)expected=yy%32<lev*2 ? pixel : 0;
@(posedge clk);#1;if(rgb!==expected || {ho,vo,deo,xo,yo}!=={hi,vi,di,x,y})$fatal(1,"pixel/axis mode=%0d level=%0d xy=%0d,%0d rgb=%h expected=%h",mode,lev,xx,yy,rgb,expected);
end endtask
initial begin
ticks(4);rst=0;ticks(8);
adjust(3);if(effect!=0)$fatal(1,"early setting");setting_frame();if(effect!=1)$fatal(1,"effect1");
adjust(3);setting_frame();if(effect!=2)$fatal(1,"effect2");adjust(3);setting_frame();if(effect!=0)$fatal(1,"effect wrap");repeat(4)adjust(3);setting_frame();if(effect!=1)$fatal(1,"queued effect");
adjust(1);setting_frame();vm=1;adjust(3);setting_frame();if(effect!=1 || volume!=4)$fatal(1,"video volume independent");vm=0;
pp=1;ticks(1);pp=0;ticks(1);ok=1;ticks(1);ok=0;ticks(2);if(page!=3)$fatal(1,"settings entry");repeat(3)begin np=1;ticks(1);np=0;ticks(1);end
ok=1;ticks(1);ok=0;ticks(2);if(page!=3 || command!=3 || !stoggle)$fatal(1,"transition setting dispatch");home=1;ticks(1);home=0;ticks(2);if(page!=0)$fatal(1,"long HOME");
pending=1;ticks(8);if(active!=1)$fatal(1,"latched effect");request=2;
for(n=15;n>=0;n=n-1)begin frame();if(fade!=n || swap!==(n==0) || active!=1)$fatal(1,"out/safe swap/locked mode %0d",n);end
repeat(5)frame();if(!swap||fade!=0)$fatal(1,"wait black");pending=0;ticks(8);for(n=1;n<=16;n=n+1)begin frame();if(fade!=n || swap)$fatal(1,"in %0d",n);end
ticks(3);if(active!=2)$fatal(1,"next transition new mode");pending=1;ticks(8);frame();ready=0;ticks(8);if(fade!=16||swap)$fatal(1,"memory recovery");pending=0;
for(k=0;k<3;k=k+1)begin mode=k;for(n=0;n<=16;n=n+1)begin lev=n;for(i=0;i<640;i=i+1)sample(i,37);for(j=0;j<480;j=j+1)sample(123,j);end end
$display("PASS all 3 effects x 17 levels, every horizontal/vertical mask position, RGB gain and one-clock HS/VS/DE/XY alignment; 16-step transaction, black-only swap, effect locking/recovery, frame-latched setting wrap/queue, video volume isolation and settings/HOME");$finish;end
initial begin #5000000;$fatal(1,"timeout");end
endmodule
