from pathlib import Path
import subprocess,os,sys
p=Path(__file__).resolve().parent.parent;kind=sys.argv[1] if len(sys.argv)>1 else 'after'
env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
s=(p/'sim/tb_av_pipeline.sv').read_text()
s=s.replace('integer byte_cycles=40;', 'integer byte_cycles=40;integer latency=0;')
s=s.replace('offset=0;active=1;', 'offset=0;active=1;latency=3500;')
s=s.replace('end else if(active && cycles%byte_cycles==0)', 'end else if(active && latency!=0)latency=latency-1;\n   else if(active && cycles%byte_cycles==0)')
s=s.replace('frames>=6','frames>=12').replace('#1000000000;', '#2000000000;')
if kind=='before':s=s.replace('if(audio_under)$fatal(1,"audio underrun in fast-card integration model");','')
s=s.replace('"card too slow: %0d silent frame-boundary ticks"','"card latency caused %0d silent frame-boundary ticks"')
bench=p/'sim/tb_av_latency.sv';bench.write_text(s)
mods=['fat32_media_stream','av_unpacker','mono_pair','audio_fifo','video_pcm_player','video_store','line_buffer','frame_video']
paths=[str((p/'sim/reference/fat32_media_stream_before_prefetch.v')) if kind=='before' and m=='fat32_media_stream' else str(p/'rtl'/f'{m}.v') for m in mods]
exe=p/'build'/f'latency_{kind}.vvp'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_av_pipeline','-o',str(exe),*paths,str(bench)],env=env,check=True)
with (p/'verification'/f'latency_{kind}.log').open('w') as log:
 proc=subprocess.Popen(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe)],env=env,cwd=p,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 for line in proc.stdout:print(line,flush=True);log.write(line);log.flush()
 sys.exit(proc.wait())
