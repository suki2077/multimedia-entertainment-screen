"""Full HQ A/V pipeline; real transport via run_sd_transport.py --job wire_pipeline."""
from pathlib import Path
import os,subprocess
p=Path(__file__).resolve().parent.parent
env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
mods=['fat32_media_stream','av_unpacker','mono_pair','audio_fifo','video_pcm_player','video_store','line_buffer','frame_video']
exe=p/'build/hq_pipeline.vvp'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_av_pipeline','-o',str(exe),*[str(p/'rtl'/f'{n}.v') for n in mods],str(p/'sim/tb_av_pipeline.sv')],env=env,check=True)
with (p/'verification/hq_pipeline.log').open('w') as log:
 proc=subprocess.Popen(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe)],cwd=p,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 for line in proc.stdout:print(line,end='',flush=True);log.write(line);log.flush()
 assert proc.wait()==0
