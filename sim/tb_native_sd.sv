`timescale 1ns/1ps
module tb_native_sd;
reg clk=0,sc=0,rst=1,power_rst=1,req=0,stream=0;reg[31:0]addr=0;always #7.5 clk=~clk;initial begin #2.5;forever #5 sc=~sc;end
tri1 cmd;wire sck;tri1 dat3;wire[3:0]dat;assign dat3=dat[3];
reg bad_crc=0,bad_response=0;wire ready,bv,se;wire[7:0]bd;
sd_native_bridge dut(.clk(clk),.sd_clk(sc),.rst(rst),.SD_nCS(dat3),.SD_MOSI(cmd),.SD_DCLK(sck),.SD_MISO(dat[0]),.SD_D1(dat[1]),.SD_D2(dat[2]),
 .sd_init_done(ready),.sd_sec_read(req),.read_stream(stream),.sd_sec_read_addr(addr),.sd_sec_read_data(bd),.sd_sec_read_data_valid(bv),.sd_sec_read_end(se),.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0));
sd_native_fixture card(power_rst,sck,cmd,dat,bad_crc,bad_response);
integer n=0,blocks=0,expected=0;time start_time,elapsed,last_edge=0;real rate;
always @(sck)if(!rst)begin if(last_edge!=0 && $time-last_edge<20)$fatal(1,"SD clock half-period below20ns");last_edge=$time;end else last_edge=0;
always @(posedge clk)if(!rst)begin
 if(bv)begin if(bd!==(((expected*17+n)^90)&255))$fatal(1,"native byte %d/%d: %h",expected,n,bd);n=n+1;end
 if(se)begin if(n!=512)$fatal(1,"sector length %d",n);blocks=blocks+1;end
end
task get;input integer lba;input multi;begin
 @(negedge clk);n=0;expected=lba;addr=lba;stream=multi;req=1;@(negedge clk);req=0;
 wait(se);@(negedge clk);
end endtask
task reset_host;begin @(negedge clk);rst=1;req=0;repeat(6)@(negedge clk);rst=0;wait(ready);repeat(3)@(negedge clk);end endtask
integer i;
initial begin
 repeat(6)@(negedge clk);power_rst=0;rst=0;wait(ready);$display("native init complete");$fflush();
 get(10,0);get(20,1);start_time=$time;
 for(i=21;i<37;i=i+1)get(i,1);
 elapsed=$time-start_time;rate=8192.0*1e9/elapsed;
 if(rate<8000000)$fatal(1,"native throughput %f",rate);
 repeat(5000)@(negedge clk);get(70,1);get(71,0);
 if(card.cmd17s!=2 || card.cmd18s!=2 || card.cmd12s!=2)$fatal(1,"command coverage %d %d %d",card.cmd17s,card.cmd18s,card.cmd12s);
 // Exercise all four transmitted address bytes and a distant seek.
 get(32'h12345678,1);get(32'h12345679,1);get(32'h03b9c900,1);
 // Reset the host during a data block without power-cycling the card.
 @(negedge clk);n=0;expected=90;addr=90;stream=1;req=1;@(negedge clk);req=0;wait(n==64);reset_host();get(100,1);
 bad_crc=1;@(negedge clk);n=0;expected=101;addr=101;req=1;@(negedge clk);req=0;wait(!ready);repeat(50)@(negedge clk);
 if(n!=511 || se)$fatal(1,"CRC failure did not withhold final byte/end: %d",n);
 bad_crc=0;reset_host();bad_response=1;
 @(negedge clk);n=0;expected=120;addr=120;stream=0;req=1;@(negedge clk);req=0;wait(!ready);repeat(50)@(negedge clk);
 if(n!=0 || se)$fatal(1,"response CRC accepted");
 $display("PASS NATIVE_SD rate_Bps=%f exact sectors=%d, commandCRC, four independent dataCRC lanes, gaps, seeks, busy, restart without card reset, corrupt response/data rejected",rate,blocks);$finish;
end
initial begin #100000000;$fatal(1,"native timeout host state=%d step=%d card stage=%d count=%d",dut.core.state,dut.core.step,card.stage,n);end
endmodule
