`timescale 1ns/1ps
module tb_library_control;
 reg clk=0,rst=1,np=0,pp=0,sp=0,lp=0,menu=0,ready=1,busy=0;always #7 clk=~clk;
 wire [2:0] page,cursor,ms,vs;wire [1:0] home,focus,cmd;wire ut,an,ap,am,st,paused,opened,restart;
 wire owner,sw,quiet;
 shell_control #(.LIBRARY(1)) d(clk,rst,np,pp,sp,lp,page,home,focus,ut,an,ap,am,cmd,st,paused,menu,ready,busy,4'd8,4'd5,opened,cursor,ms,vs,restart);
 media_owner #(.RESTARTABLE(1),.DRAIN_CYCLES(80)) own(clk,rst,page==4,owner,sw,quiet,restart);
 task press(input integer key);begin
  @(negedge clk);case(key)0:np=1;1:pp=1;2:sp=1;3:lp=1;4:menu=1;endcase
  @(negedge clk);np=0;pp=0;sp=0;lp=0;menu=0;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;press(2);if(page!=1)$fatal(1,"album entry");
  press(4);if(!opened || cursor!=0)$fatal(1,"open music");
  press(1);if(cursor!=7 || an || ap)$fatal(1,"music wrap/isolation");
  ready=0;press(2);if(!opened || restart)$fatal(1,"confirm while scanning");ready=1;
  busy=1;press(2);if(!opened || restart)$fatal(1,"confirm while switching");busy=0;
  press(2);if(opened || ms!=7 || !restart)$fatal(1,"music commit");
  @(negedge clk);if(!quiet)$fatal(1,"same-owner restart not accepted");
  wait(sw);if(owner)$fatal(1,"music owner changed");wait(!quiet);
  press(4);if(cursor!=7)$fatal(1,"remember music");press(2);if(restart)$fatal(1,"same file should keep position");
  press(3);press(0);press(2);wait(owner);wait(!quiet);if(page!=4)$fatal(1,"video entry");
  press(4);press(1);if(cursor!=4)$fatal(1,"video wrap");press(2);if(vs!=4 || !restart || paused)$fatal(1,"video commit");
  wait(quiet);wait(sw);if(!owner)$fatal(1,"video owner changed");wait(!quiet);
  press(2);if(!paused)$fatal(1,"pause");press(4);press(4);if(!paused || opened)$fatal(1,"cancel preserves pause");
  press(4);press(3);if(opened || page!=0)$fatal(1,"home closes list");
  $display("PASS music/video independent selections, 4-row page wrap, scan/busy gating, commit/cancel, pause preservation, same-owner restart/drain/reset, HOME");$finish;
 end
 initial begin #1000000;$fatal(1,"control timeout");end
endmodule
