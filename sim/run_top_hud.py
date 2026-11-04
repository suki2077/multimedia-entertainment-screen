from pathlib import Path
import os,subprocess
p=Path(__file__).resolve().parent.parent;env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
vvp=p/'build/test_top_hud.vvp'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_top_hud','-o',str(vvp),str(p/'rtl/video_hud.v'),str(p/'rtl/subtitle_overlay.v'),str(p/'sim/tb_top_hud.sv')],env=env,check=True)
r=subprocess.run(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(vvp)],cwd=p,env=env,capture_output=True,text=True)
(p/'verification/top_hud.log').write_text(r.stdout+r.stderr);print(r.stdout+r.stderr);assert r.returncode==0 and 'PASS' in r.stdout
