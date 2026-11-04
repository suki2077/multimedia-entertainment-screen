`timescale 1ns/1ps
module tb_library_restart;
 reg mc=0,pc=0,rst=1,restart=0,want=0;always #7 mc=~mc;always #20 pc=~pc;
 wire owner,sw,quiet;reg sm=0,sp=0;reg valid=0,pop=0;reg [31:0] word=0;wire ready,rv;wire [31:0] data;wire [3:0] wl,rl;
 media_owner #(.RESTARTABLE(1),.DRAIN_CYCLES(80)) own(mc,rst,want,owner,sw,quiet,restart);
 always @(posedge pc or posedge rst)if(rst)begin sm<=0;sp<=0;end else begin sm<=sw;sp<=sm;end
 audio_fifo #(.A(3)) fifo(mc,pc,rst,valid && !sw,word,ready,pop,rv,data,wl,rl,sw,sp);
 task push(input [31:0] value);begin
  @(negedge mc);word=value;valid=1;while(!ready)@(negedge mc);@(negedge mc);valid=0;
 end endtask
 task take(input [31:0] value);begin
  wait(rv);@(negedge pc);if(data!==value)$fatal(1,"stale audio %h instead of %h",data,value);pop=1;@(negedge pc);pop=0;repeat(4)@(negedge pc);
 end endtask
 task restart_file;begin
  @(negedge mc);restart=1;@(negedge mc);restart=0;
  if(!quiet)$fatal(1,"no drain");wait(sw);wait(!quiet);repeat(8)@(negedge pc);
  if(rv || wl!=0 || rl!=0)$fatal(1,"old audio survived restart");
 end endtask
 initial begin
  repeat(5)@(negedge pc);rst=0;repeat(8)@(negedge pc);
  push(32'h11111111);push(32'hdeadbeef);take(32'h11111111);restart_file();
  if(owner)$fatal(1,"music restart changed owner");push(32'h22222222);take(32'h22222222);
  @(negedge mc);want=1;wait(quiet);wait(!quiet);repeat(8)@(negedge pc);
  push(32'haaaaaaaa);push(32'hcccccccc);take(32'haaaaaaaa);restart_file();
  if(!owner)$fatal(1,"video restart changed owner");push(32'hbbbbbbbb);take(32'hbbbbbbbb);
  $display("PASS same-owner music and video file restart: drain window + actual two-clock FIFO flush, stale samples discarded, new samples exact");$finish;
 end
 initial begin #1000000;$fatal(1,"restart timeout");end
endmodule
