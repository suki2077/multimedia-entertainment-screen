`timescale 1ns/1ps
module tb_packed_line;
reg wc=0,rc=0,we=0;always #7 wc=~wc;always #20 rc=~rc;
reg[10:0] wa=0,ra=0;reg[23:0] wd=0;wire[23:0] q;
line_buffer d(wc,we,wa,wd,rc,ra,q);
integer generation=0,bank,n,j;reg[23:0] ref0[0:639],ref1[0:639];
function[23:0] pattern(input integer gen,b,x);begin pattern=24'(gen*34567+b*43981+x*1297);end endfunction
task check(input integer b,x);begin @(negedge rc);ra=b*1024+x;@(posedge rc);#1;if(q!==(b?ref1[x]:ref0[x]))$fatal(1,"packed read b=%d x=%d got=%h",b,x,q);end endtask
task write_row(input integer b,gen);begin
 for(j=0;j<640;j=j+1)begin
  @(negedge wc);we=1;wa=b*1024+j;wd=pattern(gen,b,j);
  if(b)ref1[j]=wd;else ref0[j]=wd;
  if(j%17==3)begin @(negedge wc);we=0;repeat(2)@(negedge wc);end
 end
 @(negedge wc);we=0;
end endtask
initial begin
write_row(0,1);write_row(1,2);
for(bank=0;bank<2;bank=bank+1)for(n=0;n<640;n=n+1)check(bank,n);
for(generation=3;generation<7;generation=generation+1)begin
 bank=generation%2;
 fork
  write_row(bank,generation);
  begin for(n=0;n<100;n=n+1)check(1-bank,(n*193)%640);end
 join
 for(n=0;n<640;n=n+1)check(bank,(n*193)%640);
end
// Every 640th pixel is a partial group, not a stale preceding row pixel.
check(0,639);check(1,639);check(0,0);check(1,0);
$display("PASS packed line buffer: both 640-pixel RGB888 rows, every slot/address, asynchronous clocks, write stalls, concurrent opposite-bank reads, four row rewrites and partial-group tails");$finish;
end
endmodule
