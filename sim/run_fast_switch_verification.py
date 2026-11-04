from pathlib import Path
import os,sys,subprocess
p=Path(__file__).resolve().parent.parent
env=os.environ.copy();env['TMP']=env['TEMP']='D:/FPGA/tf_console_bluetooth_38400/sim_tmp'
env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH']
def run(name,mods,opts=(),extra=()):
 exe=p/'build'/f'{name}.vvp'
 cmd=['D:/FPGA/rtl_sim_tools/bin/iverilog.exe','-g2012','-s','tb_'+name,'-o',str(exe),*[str(p/'rtl'/f'{m}.v') for m in mods],*[str(p/'sim'/f'{m}.sv') for m in extra],str(p/'sim'/f'tb_{name}.sv')]
 r=subprocess.run(cmd,env=env,capture_output=True,text=True,errors='replace');assert r.returncode==0,r.stdout+r.stderr
 lines=[]
 tag=name+('_'+opts[0].replace('+','').replace('=','_').replace('/','_') if opts else '')
 with (p/'verification'/f'{tag}.log').open('w') as log:
  proc=subprocess.Popen(['D:/FPGA/rtl_sim_tools/bin/vvp.exe',str(exe),*opts],cwd=p,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace')
  for line in proc.stdout:
   print(line,end='',flush=True);log.write(line);log.flush();lines.append(line)
  code=proc.wait()
 assert code==0 and any('PASS' in line for line in lines),name


if __name__=='__main__':
 for name in ['build','verification','preview']:(p/name).mkdir(exist_ok=True)
 photo=['fat32_bmp_loader','bmp_fit_scaler','scale_divider','scale_lerp','album_line_buffer']
 native=['sd_read_bridge','sd_card_top','sd_card_cmd','sd_card_sec_read_write','spi_master']
 run('runner_slide',['runner_core'])
 for name in ['arcade_playthrough','breakout_polish']:run(name,['breakout_core'])
 for name in ['cache_control','album20_tagged']:run(name,['cache_album_control'])
 run('sector_count',['fat32_media_stream']+photo)
 for n in [0,4,20,21]:run('album20_reader',photo,opts=['+DIR=sim/fixtures/album20/'+str(n)])
 for name in ['wav_cache','av_reader']:run(name,['fat32_media_stream'])
 run('sd20',native)
 for mode in [1,0]:run('photo_native',native+photo,opts=['+STREAM='+str(mode)],extra=['sd_latency_fixture'])
 for name in ['media_latency','media_serial']:
  run(name,native+['sd_read_arbiter','fat32_media_stream','audio_fifo','pcm_player'],extra=['sd_latency_fixture'])
 run('arcade_events',['shell_control','arcade_input','ui_state_cdc','breakout_core'])
 for name in ['arcade_fx_preview','delivery_preview']:run(name,['arcade_renderer'])
 if '--full-cache' in sys.argv:run('album20_store',['frame_store_cached'])
 print('PASS fast switching verification; real board acceptance remains required')
