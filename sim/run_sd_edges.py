from pathlib import Path
import os,subprocess
p=Path(__file__).resolve().parent.parent
env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
exe=p/'build/hq_sd_edges.vvp'
mods=['spi_master','sd_card_cmd','sd_card_sec_read_write','sd_card_top']
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_sd_edges','-o',str(exe),*[str(p/'rtl'/f'{n}.v') for n in mods],str(p/'sim/tb_sd_multiread.sv'),str(p/'sim/tb_sd_edges.sv')],env=env,check=True)
r=subprocess.run(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe)],cwd=p,env=env,capture_output=True,text=True)
(p/'verification/hq_sd_edges.log').write_text(r.stdout+r.stderr);print(r.stdout,flush=True)
assert r.returncode==0 and 'high minimum=15.000000 ns low minimum=30.000000 ns' in r.stdout
