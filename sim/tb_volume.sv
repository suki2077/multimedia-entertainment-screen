`timescale 1ns/1ps
module tb_volume;
reg clk=0,rst=1;always #5 clk=~clk;
reg [2:0] volume=0;reg physical_sound=1;
wire sound=physical_sound && volume!=0;
reg [31:0] data=0;wire pop,av,acr,playing,under;wire [23:0] left_data,right_data;
pcm_player #(.PREFILL(2)) d(clk,rst,sound,1'b1,data,13'd16,pop,av,acr,left_data,right_data,playing,under,volume);
integer frames=0,acrs=0,cycles=0,last_cycle=0,block_no,factor,ls,rs,el,er;reg was_pop;
function [15:0] pattern(input integer n);
begin case(n%8)
0:pattern=16'h8000;1:pattern=16'h7fff;2:pattern=16'hffff;3:pattern=16'h0001;
4:pattern=16'h0000;5:pattern=16'hc123;6:pattern=16'h4567;default:pattern=n*131+73;
endcase end endfunction
always @(negedge clk)begin
 block_no=frames/96;volume=block_no%5;physical_sound=!(block_no==5 || block_no==11);
 data={pattern(frames+3),pattern(frames)};
end
always @(posedge clk)if(!rst)begin
 cycles=cycles+1;was_pop=pop;
 ls=$signed(data[15:0]);rs=$signed(data[31:16]);factor=sound?(volume*64):0;
 el=ls*factor;er=rs*factor;
 #1;
 if(under)$fatal(1,"unexpected underrun");
 if(av!==was_pop)$fatal(1,"FIFO/audio cadence diverged");
 if(av)begin
  if(frames>0 && cycles-last_cycle!=520 && cycles-last_cycle!=521)$fatal(1,"sample cadence %d",cycles-last_cycle);
  last_cycle=cycles;
  if($signed(left_data)!==el || $signed(right_data)!==er)$fatal(1,"gain frame %d level %d sound %b: %d,%d expected %d,%d",frames,volume,sound,$signed(left_data),$signed(right_data),el,er);
  if(acr!==((frames%48)==47))$fatal(1,"ACR cadence");
  if(acr)acrs=acrs+1;frames=frames+1;
  if(frames==1152)begin
   if(acrs!=24)$fatal(1,"ACR count");
   $display("PASS 1152 stereo PCM frames: all five amplitude levels, signed extrema, fractional precision, independent mute, uninterrupted FIFO progress, 48k cadence and 24 ACR packets");$finish;
  end
 end
end
initial begin repeat(4)@(negedge clk);rst=0;end
initial begin #8000000;$fatal(1,"volume timeout");end
endmodule
