from pathlib import Path
import subprocess,os,sys
p=Path(__file__).resolve().parent.parent;kind=sys.argv[1] if len(sys.argv)>1 else 'after'
env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
s=(p/'sim/tb_av_reader.sv').read_text()
s=s.replace('wire sample_ready=(cycles%47<35) && !(n==1000 && pause_count<5000);','''wire sample_ready;wire vv,av;wire [31:0] vd;wire [15:0] ad;
 integer cool=0,group_words=0,begin_cycle=0,elapsed=0,token_wait=0;
 av_unpacker unpack(clk,rst,sv,sample,sample_ready,vv,vd,cool==0,av,ad,1'b1);
 always @(posedge clk)begin
  if(cool!=0)cool<=cool-1;
  else if(vv)begin
   if(group_words==3)begin group_words<=0;cool<=36;end
   else group_words<=group_words+1;
  end
 end''')
s=s.replace('.IO_TIMEOUT(2000)', '.IO_TIMEOUT(10000)')
s=s.replace('offset=0;active=1;', 'offset=0;active=1;token_wait=3500;')
s=s.replace('end else if(active && cycles%2==0)', 'end else if(active && token_wait!=0)token_wait=token_wait-1;\n  else if(active && cycles%40==0)')
s=s.replace('n=n+1;', 'if(n==0)begin_cycle=cycles;n=n+1;')
s=s.replace('|| pause_count!=5000','')
s=s.replace('$display("PASS fragmented', 'elapsed=cycles-begin_cycle;$display("MEASURE two_packets_ns=%0d effective_Bps=%0f",elapsed*14,188416.0*1e9/(elapsed*14));\n   $display("PASS fragmented')
s=s.replace('#100000000;', '#500000000;')
bench=p/'sim/tb_feed_rate.sv';bench.write_text(s);exe=p/'build'/f'feed_{kind}.vvp'
reader=(p/'sim/reference/fat32_media_stream_before_prefetch.v') if kind=='before' else p/'rtl/fat32_media_stream.v'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_av_reader','-o',str(exe),str(reader),str(p/'rtl/av_unpacker.v'),str(bench)],env=env,check=True)
r=subprocess.run(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe),'+DIR=sim/fixtures/video/partition'],env=env,cwd=p,capture_output=True,text=True)
(p/'verification'/f'feed_{kind}.log').write_text(r.stdout+r.stderr);print(r.stdout);assert r.returncode==0,r.stderr
