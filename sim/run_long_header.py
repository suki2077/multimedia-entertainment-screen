from pathlib import Path
import os,subprocess
p=Path(__file__).resolve().parent.parent;env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
s=(p/'sim/tb_av_reader.sv').read_text()
s=s.replace("dut.video_total_frames!==15'd2", "dut.video_total_frames!==((mode==4)?15'd27000:15'd2)")
s=s.replace('if(failed)begin','if(mode==4 && n==40000)begin $display("PASS 30-minute header accepted, first 40000 words exact");$finish;end\n  if(failed)begin')
s=s.replace('(mode==1 && err==6)', '((mode==1 || mode==5) && err==6)')
s=s.replace('  repeat(4)@(negedge clk);rst=0;', '''  if(mode==4 || mode==5)begin
   for(i=0;i<count;i=i+1)begin
    if(lbas[i]==first)begin
     {disk[i*512+19],disk[i*512+18],disk[i*512+17],disk[i*512+16]}=(mode==4)?32'd27000:32'd27001;
     {disk[i*512+23],disk[i*512+22],disk[i*512+21],disk[i*512+20]}=((mode==4)?32'd27000:32'd27001)*32'd133632;
    end
    for(integer j=0;j<512;j=j+32)if({disk[i*512+j],disk[i*512+j+1],disk[i*512+j+2],disk[i*512+j+3],disk[i*512+j+4],disk[i*512+j+5],disk[i*512+j+6],disk[i*512+j+7],disk[i*512+j+8],disk[i*512+j+9],disk[i*512+j+10]}==88'h564944454f202020534156)
     {disk[i*512+j+31],disk[i*512+j+30],disk[i*512+j+29],disk[i*512+j+28]}=((mode==4)?32'd27000:32'd27001)*32'd133632+512;
   end
  end
  repeat(4)@(negedge clk);rst=0;''')
bench=p/'sim/tb_long_header.sv';bench.write_text(s);exe=p/'build/long_header.vvp'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_av_reader','-o',str(exe),str(p/'rtl/fat32_media_stream.v'),str(bench)],env=env,check=True)
out=''
for mode in [4,5]:
 r=subprocess.run(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe),'+DIR=sim/fixtures/video/partition',f'+MODE={mode}'],env=env,cwd=p,capture_output=True,text=True)
 print(r.stdout);assert r.returncode==0 and 'PASS' in r.stdout,r.stdout;out+=r.stdout
(p/'verification/long_header.log').write_text(out)
