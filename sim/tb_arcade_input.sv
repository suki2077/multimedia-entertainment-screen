`timescale 1ns/1ps
module tb_arcade_input;
reg clk=0,rst=1,l=1,r=1,toggle=0;always #5 clk=~clk;
wire lh,rh,lc,rc,ok;integer nl=0,nr=0,no=0;
arcade_input #(.SAMPLE_CYCLES(3)) d(clk,rst,l,r,toggle,lh,rh,lc,rc,ok);
always @(posedge clk)begin if(lc)nl=nl+1;if(rc)nr=nr+1;if(ok)no=no+1;end
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
initial begin
ticks(3);rst=0;ticks(8);l=0;ticks(1);l=1;ticks(20);if(nl || lh)$fatal(1,"bounce");
l=0;ticks(30);if(!lh || nl!=1)$fatal(1,"left hold");ticks(30);if(nl!=1)$fatal(1,"held repeats click");
r=0;ticks(30);if(!rh || nr!=1 || !lh)$fatal(1,"both keys");
l=1;r=1;ticks(30);if(lh || rh)$fatal(1,"release");
toggle=1;ticks(20);if(no!=1)$fatal(1,"toggle CDC");toggle=0;ticks(20);if(no!=2)$fatal(1,"second CDC");
$display("PASS arcade input bounce rejection, held levels, one click per press, simultaneous keys, release and KEY4 toggle CDC");$finish;
end
endmodule
