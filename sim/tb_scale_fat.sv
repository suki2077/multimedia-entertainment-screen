`timescale 1ns/1ps
module tb_scale_fat;
 reg clk=0;always #5 clk=~clk;
 reg rst=1;wire req,gv,done,failed;wire[31:0] lba;wire[20:0] ga;wire[127:0] gd;wire[7:0] err;wire[5:0] state;
 reg bv=0,send=0;reg[7:0] bd=0;reg se=0;integer index=0,mode=0,expected_err=0,cycles=0,groups=0;
 integer count,selected,delay_count=0,bi=0,fd,i,first_lba,badfat,badoffset;
 reg[31:0] lbas[0:16383];reg[7:0] bytes[0:8388607];
 reg[1023:0] folder,outname;string path;reg[1:0] img;
 wire ready=cycles%47<35;
 fat32_bmp_loader #(.INIT_TIMEOUT(10000),.IO_TIMEOUT(10000)) dut(
 .clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.image_index(img),
 .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),
 .group_valid(gv),.group_ready(ready),.group_addr(ga),.group_data(gd),.done(done),.failed(failed),.error_code(err),.debug_state(state));
 always @(posedge clk)if(!rst)begin
  cycles<=cycles+1;
  if(req)begin
   if(send)$fatal(1,"overlapping sector requests");
   selected=-1;for(i=0;i<count;i=i+1)if(lbas[i]==lba)selected=i;
   if(selected<0)$fatal(1,"unknown LBA %d",lba);
   bi<=0;delay_count<=3;send<=1;
  end
  bv<=0;se<=0;
  if(send)begin
   if(delay_count!=0)delay_count<=delay_count-1;
   else if(mode==5 && lba==first_lba)begin end
   else begin
    if(bi<512)begin
     bv<=1;bd<=bytes[selected*512+bi];bi<=bi+1;delay_count<=1;
     if(mode==1 && lba==first_lba && bi==510)begin se<=1;send<=0;end
    end else begin se<=1;send<=0;end
   end
  end
  if(gv&&ready)begin $fdisplay(fd,"%06x %032x",ga,gd);groups<=groups+1;end
  if(failed)begin
   if(expected_err==0||err!=expected_err)$fatal(1,"unexpected error %02x state %d",err,state);
   $display("PASS FAT error mode=%0d code=%02x groups=%0d",mode,err,groups);$fclose(fd);$finish;
  end
  if(done)begin
   if(expected_err!=0||groups!=76800)$fatal(1,"wrong completion groups %d",groups);
   $display("PASS FAT image=%0d cycles=%0d groups=%0d",index,cycles,groups);$fclose(fd);$finish;
  end
  if(cycles>26000000)$fatal(1,"timeout state=%d scale=%d sy=%d",state,dut.u_scaler.state,dut.u_scaler.sy);
 end
 initial begin
  if(!$value$plusargs("DIR=%s",folder))folder="sim/fixtures/partition";
  if(!$value$plusargs("COUNT=%d",count))$fatal;
  if(!$value$plusargs("INDEX=%d",index))index=0;
  if(!$value$plusargs("MODE=%d",mode))mode=0;
  if(!$value$plusargs("ERR=%d",expected_err))expected_err=0;
  if(!$value$plusargs("FIRST=%d",first_lba))first_lba=0;
  if(!$value$plusargs("FAT=%d",badfat))badfat=0;
  if(!$value$plusargs("OFFSET=%d",badoffset))badoffset=0;
  if(!$value$plusargs("OUT=%s",outname))outname="build/fat.txt";
  path=$sformatf("%0s/lbas.hex",folder);$readmemh(path,lbas,0,count-1);
  path=$sformatf("%0s/data.hex",folder);$readmemh(path,bytes,0,count*512-1);
  if(mode==2)for(i=0;i<count;i=i+1)if(lbas[i]==badfat)begin
   bytes[i*512+badoffset]=8'hff;bytes[i*512+badoffset+1]=8'hff;
   bytes[i*512+badoffset+2]=8'hff;bytes[i*512+badoffset+3]=8'h0f;
  end
  if(mode==3)for(i=0;i<count;i=i+1)if(lbas[i]==0)bytes[i*512+510]=0;
  img=index;fd=$fopen(outname,"w");repeat(4)@(negedge clk);rst=0;
 end
endmodule
