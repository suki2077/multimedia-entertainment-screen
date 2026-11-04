`timescale 1ns/1ps
module tb_fifo_handover;
 reg mc=0,pc=0,rst=1,wf=0,rf=0,prst=1,mv=0,mono_mode=0;always #7 mc=~mc;always #20 pc=~pc;
 reg [31:0] music=0;reg pv=0;reg [15:0] pd=0;wire pw,pair_valid,fw,rv;wire [31:0] pair_word,out;
 reg pop=0;wire [3:0] wl,rl;
 mono_pair pair(mc,prst,pv,pd,pw,pair_valid,pair_word,fw && mono_mode);
 audio_fifo #(.A(3)) fifo(mc,pc,rst,mono_mode?pair_valid:mv,mono_mode?pair_word:music,fw,pop,rv,out,wl,rl,wf,rf);
 task push(input [31:0] value);begin @(negedge mc);music=value;mv=1;while(!fw)@(negedge mc);@(negedge mc);mv=0;end endtask
 task sample(input [15:0] value);begin @(negedge mc);pd=value;pv=1;while(!pw)@(negedge mc);@(negedge mc);pv=0;end endtask
 task check(input [31:0] value);begin wait(rv);@(negedge pc);if(out!==value)$fatal(1,"stale/mixed FIFO word got=%h expected=%h",out,value);pop=1;@(negedge pc);pop=0;repeat(3)@(negedge pc);end endtask
 task flush;begin
  @(negedge mc);wf=1;prst=1;
  repeat(2)@(negedge pc);rf=1;
  repeat(20)@(negedge mc);wf=0;
  repeat(4)@(negedge pc);rf=0;
  repeat(5)@(negedge pc);if(rv || wl!=0 || rl!=0 || pair.half)$fatal(1,"flush not empty");
 end endtask
 initial begin
  repeat(5)@(negedge pc);rst=0;repeat(8)@(negedge pc);
  push(32'h12345678);push(32'hdeadbeef);push(32'h98765432);check(32'h12345678);
  mono_mode=1;prst=0;sample(16'hbad0);flush();prst=0;
  sample(16'h0001);sample(16'h8000);sample(16'h7fff);sample(16'hffff);
  check(32'h80000001);check(32'hffff7fff);flush();mono_mode=0;
  push(32'hcafebabe);check(32'hcafebabe);
  $display("PASS WAV -> mono-pair video -> WAV FIFO handover: independently synchronized flushes, stale data discarded, half packet discarded, exact new words");$finish;
 end
 initial begin #1000000;$fatal(1,"FIFO handover timeout");end
endmodule
