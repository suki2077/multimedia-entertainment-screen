from pathlib import Path
import subprocess,os,json
p=Path(__file__).resolve().parent.parent;env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
base='D:/FPGA/rtl_sim_tools/bin/'
jobs={'line_smooth':['line_buffer'],'runner_polish_preview':['arcade_renderer'],'renderer_equivalence':['arcade_renderer','../sim/arcade_renderer_reference'],'switch_game_preview':['arcade_renderer'],'switch_settings':['shell_overlay'],'library_switch':['library_switch','shell_control','media_controls'],'auto_transition':['fade_control'],'transition':['fade_pipe','fade_control','media_controls','shell_control'],'transition_ui':['shell_overlay'],'breakout_equivalence':['breakout_core','../sim/breakout_reference'],'runner':['runner_core'],'runner_menu':['breakout_core','runner_core'],'render_runner':['arcade_renderer'],'bmp_bounds':['fat32_bmp_loader','bmp_fit_scaler','scale_divider','scale_lerp','album_line_buffer'],'arcade_axis':['arcade_renderer','rgb_to_axis'],'audio_viz':['audio_wave_overlay','video_hud'],'fifo_handover':['audio_fifo','mono_pair'],'home_preview':['shell_overlay'],'av_unpacker':['av_unpacker'],'owner':['media_owner'],'shared_line':['line_buffer'],'shell':['shell_control','key_action'],'ui_cdc':['ui_state_cdc'],'volume_controls':['media_controls'],'alignment':['shell_overlay','rgb_to_axis'],'breakout':['breakout_core'],'scale_math':['scale_divider','scale_lerp'],'av_reader':['fat32_media_stream'],'volume_music':['fat32_media_stream','sd_read_arbiter','audio_fifo','pcm_player'],'scale_music':['fat32_bmp_loader','bmp_fit_scaler','scale_divider','scale_lerp','album_line_buffer','fat32_media_stream','sd_read_arbiter','audio_fifo','pcm_player']}
import sys
for name in sys.argv[1:] or list(jobs):
 files=jobs[name];exe=p/'build'/f'test_{name}.vvp'
 r=subprocess.run([base+'iverilog.exe','-g2012','-s','tb_'+name,'-o',str(exe),*[str(p/'rtl'/f'{f}.v') for f in files],str(p/'sim'/f'tb_{name}.sv')],env=env,capture_output=True,text=True)
 assert r.returncode==0,r.stdout+r.stderr
 cases=[[]]
 if name=='av_reader':cases=[['+DIR=sim/fixtures/video/partition'],['+DIR=sim/fixtures/video/superfloppy'],['+MODE=1'],['+MODE=2'],['+DIR=sim/fixtures/video/partition','+MODE=3']]
 if name=='scale_music':cases=[[f'+COUNT={json.loads((p/"sim/fixtures/shared/meta.json").read_text())["count"]}']]
 for i,args in enumerate(cases):
  r=subprocess.run([base+'vvp.exe',str(exe),*args],cwd=p,env=env,capture_output=True,text=True)
  out=r.stdout+r.stderr;(p/'verification'/f'{name}_{i}.log').write_text(out);print(out,flush=True)
  assert r.returncode==0 and 'PASS' in out and 'FATAL' not in out,name
