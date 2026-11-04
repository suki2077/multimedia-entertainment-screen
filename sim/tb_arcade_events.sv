`timescale 1ns/1ps
module tb_arcade_events;
reg mc=0,pc=0,rst=1,np=0,pp=0,sp=0,lp=0,vs=1;
always #7 mc=~mc;always #20 pc=~pc;
wire[2:0] page,vpage;wire[1:0] home,focus,command,vhome,vfocus;wire ut,an,ap,am,st;
shell_control s(mc,rst,np,pp,sp,lp,page,home,focus,ut,an,ap,am,command,st,,1'b0,1'b0,1'b0,4'd0,4'd0,,,,,);
reg toggle=0;always @(posedge mc or posedge rst)if(rst)toggle<=0;else if(sp && page==2)toggle<=~toggle;
wire lh,rh,lc,rc,ok;
arcade_input #(.SAMPLE_CYCLES(3)) i(pc,rst,1'b1,1'b1,toggle,lh,rh,lc,rc,ok);
ui_state_cdc c(pc,rst,vs,ut,{page,home,focus},vpage,vhome,vfocus);
wire view;wire[2:0] state;
breakout_core g(.clk(pc),.rst(rst),.vs(vs),.active(vpage==2),.left_held(lh),.right_held(rh),.left_click(lc),.right_click(rc),.confirm(ok),.view_game(view),.state(state));
task mt(input integer n);begin repeat(n)@(negedge mc);end endtask
task pt(input integer n);begin repeat(n)@(negedge pc);end endtask
task frame;begin vs=0;pt(2);vs=1;pt(45);end endtask
task click;begin @(negedge mc);sp=1;mt(1);sp=0;mt(4);end endtask
task enter;begin np=1;mt(1);np=0;mt(5);np=1;mt(1);np=0;mt(5);click();pt(10);frame();frame();end endtask
initial begin
mt(5);rst=0;mt(4);enter();
if(vpage!=2 || view)$fatal(1,"HOME entry confirm leaked into game menu");
click();pt(10);frame();if(!view || state!=0)$fatal(1,"game select");
click();pt(10);frame();if(state!=1)$fatal(1,"start");
click();pt(10);frame();if(state!=2)$fatal(1,"pause");
@(negedge mc);lp=1;mt(1);lp=0;pt(10);frame();frame();if(vpage!=0 || view)$fatal(1,"long HOME");
click();pt(10);frame();frame();if(vpage!=2 || view)$fatal(1,"reentry confirm leaked");
$display("PASS integrated memory/pixel clock navigation, entry event isolation, game select/start/pause and global HOME/reentry");$finish;
end
initial begin #1000000;$fatal(1,"events timeout");end
endmodule
