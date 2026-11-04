import os,subprocess
from pathlib import Path
p=Path(__file__).resolve().parent.parent;env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
exe=p/'build/test_audio_viz.vvp'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_audio_viz','-o',str(exe),str(p/'rtl/audio_wave_overlay.v'),str(p/'rtl/video_hud.v'),str(p/'sim/tb_audio_viz.sv')],env=env,check=True)
r=subprocess.run(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe),'+RENDER'],cwd=p,env=env,capture_output=True,text=True)
(p/'verification/gradient_render.log').write_text(r.stdout+r.stderr);print(r.stdout);assert r.returncode==0 and 'PASS' in r.stdout and 'FATAL' not in r.stdout
