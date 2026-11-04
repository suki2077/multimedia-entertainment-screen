`timescale 1ns/1ps
module tb_dynamic_title_reader;
 reg clk=0,rst=1,bv=0,se=0;always #5 clk=~clk;
 reg [7:0] bd=0;wire req,sv,done,failed,tw,tb,tc,ce,cd;wire [31:0] lba,sample;
 wire [7:0] err,td;wire [11:0] ta;wire [3:0] count;
 integer kind=0,selected=0,expect_commit=1,n=0,i,k,index,offset=0,serving=0,samples=0,writes=0,commits=0,begins=0,cycles=0;
 reg [31:0] info[0:0],lbas[0:63];reg [7:0] disk[0:32767],expected[0:4095];reg [4095:0] seen=0;
 string folder,path;
 fat32_media_stream #(.SELECTABLE(1),.TITLES(1),.INIT_TIMEOUT(10000),.IO_TIMEOUT(10000)) d(
 .clk(clk),.rst(rst),.enable(1'b1),.sd_ready(1'b1),.io_wait(1'b0),.video_mode(kind!=0),.selected_file(selected[2:0]),
 .sector_req(req),.sector_lba(lba),.byte_valid(bv),.byte_data(bd),.sector_end(se),.sample_valid(sv),.sample_ready(cycles%7<5),.sample_data(sample),
 .done(done),.failed(failed),.error_code(err),.catalog_entry(ce),.catalog_count(count),.catalog_done(cd),
 .title_write(tw),.title_addr(ta),.title_data(td),.title_begin(tb),.title_commit(tc));
 always @(negedge clk)begin
  bv=0;se=0;cycles=cycles+1;
  if(!rst)begin
   if(req)begin
    if(serving)$fatal(1,"overlapping sector request");
    index=-1;for(i=0;i<info[0];i=i+1)if(lbas[i]==lba)index=i;
    if(index<0)$fatal(1,"unknown LBA %d state %d",lba,d.state);
    serving=1;offset=0;
   end else if(serving)begin
    if(offset<512)begin bv=1;bd=disk[index*512+offset];offset=offset+1;end
    else begin se=1;serving=0;end
   end
  end
 end
 always @(posedge clk)if(!rst)begin
  if(tb)begins=begins+1;
  if(tc)begin commits=commits+1;if(writes!=2560)$fatal(1,"title write count %d",writes);end
  if(tw)begin
   writes=writes+1;
   if(expect_commit && (td!==expected[ta] || seen[ta]))$fatal(1,"title write address %h got %h wanted %h duplicate%b pos%d",ta,td,expected[ta],seen[ta],d.title_pos);
   seen[ta]=1;
  end
  if(failed)$fatal(1,"media failure %h state%d",err,d.state);
  if(sv && cycles%7<5)begin
   if(sample!==32'h12340000+selected*256+samples)$fatal(1,"PCM/video changed: %h",sample);
   samples=samples+1;
   if(samples==4)begin
    if(count!=8 || commits!=expect_commit)$fatal(1,"catalog/commit mismatch count%d commits%d",count,commits);
    if(expect_commit)begin
     for(k=0;k<2048;k=k+1)if(!seen[k] || !seen[2048+k/4])$fatal(1,"missing title byte");
    end
    $display("PASS dynamic title reader kind%0d selected%0d: %0d exact title writes, %0d commits, %0d invalidations; reordered identity join, fragmented metadata, exact media samples/backpressure",kind,selected,writes,commits,begins);$finish;
   end
  end
 end
 initial begin
  if(!$value$plusargs("DIR=%s",folder))$fatal(1,"DIR needed");
  n=$value$plusargs("KIND=%d",kind);n=$value$plusargs("SELECT=%d",selected);n=$value$plusargs("COMMIT=%d",expect_commit);
  path={folder,"/info.hex"};$readmemh(path,info);path={folder,"/lbas.hex"};$readmemh(path,lbas,0,info[0]-1);path={folder,"/data.hex"};$readmemh(path,disk,0,info[0]*512-1);
  path=$sformatf("sim/fixtures/dynamic_titles/expected%0d.hex",kind);$readmemh(path,expected);
  repeat(5)@(negedge clk);rst=0;
 end
 initial begin #10000000;$fatal(1,"title reader timeout state%d",d.state);end
endmodule
