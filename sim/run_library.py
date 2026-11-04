from pathlib import Path
import os,struct,subprocess,json
p=Path(__file__).resolve().parent.parent
env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
base='D:/FPGA/rtl_sim_tools/bin/'
def put(buf,off,fmt,*values):struct.pack_into('<'+fmt,buf,off,*values)
def entry(name,cluster,size,attr=32):
 b=bytearray(32);b[:11]=name;put(b,11,'B',attr);put(b,20,'H',cluster>>16);put(b,26,'H',cluster&65535);put(b,28,'I',size);return b
for label,video,number,eoc in [('music',False,9,False),('video',True,9,False),('eoc',False,2,True),('empty',False,0,False)]:
 boot=bytearray(512);put(boot,11,'H',512);boot[13]=1;put(boot,14,'H',32);boot[16]=1;put(boot,32,'I',70000);put(boot,36,'I',600);put(boot,44,'I',2);put(boot,510,'H',0xaa55)
 fat=bytearray(512);put(fat,8,'I',4);put(fat,16,'I',0xfffffff)
 root=bytearray(b'\xe5'+bytes(31))*32
 root[0:32]=entry(b'VOLUME     ',0,100,8)
 root[32:64]=entry(b'FOLDER  WAV',10,100,16)
 root[64:96]=entry(b'LFNFILE WAV',10,100,15)
 root[96:128]=entry(b'BADCLUS WAV',1,100)
 root[128:160]=entry(b'SMALL   WAV',10,3)
 root[160:192]=entry(b'IGNORE  TXT',10,100)
 root[192:224]=entry(b'\xe5ELETED WAV',10,100)
 root[224:256]=entry(b'OTHER   '+(b'WAV' if video else b'SAV'),22,60 if video else 134144)
 disk={0:boot,32:fat}
 ext=b'SAV' if video else b'WAV'
 for j in range(number):
  pos=(15+j)*32;root[pos:pos+32]=entry(bytes([65+j])+b' '*7+ext,10+j,134144 if video else 60)
  head=bytearray(512)
  payload=b''.join(struct.pack('<I',0x12340000+j*256+n) for n in range(4))
  if video:
   head[:8]=b'SUKIPL01';put(head,8,'6H',480,270,15,5,1,0);put(head,20,'I',133632);put(head,24,'I',24000);put(head,28,'HHI',1600,16,133632)
   disk[632+10+j-2+1]=bytearray(payload+bytes(512-len(payload)))
   # File first sector uses its own cluster; next sector follows its FAT chain.
   nxt=100+j;put(fat,(10+j)*4,'I',nxt);disk[632+nxt-2]=bytearray(payload+bytes(512-len(payload)))
  else:
   head[:4]=b'RIFF';put(head,4,'I',52);head[8:16]=b'WAVEfmt ';put(head,16,'IHHIIHH',16,1,2,48000,192000,4,16);head[36:40]=b'data';put(head,40,'I',16);head[44:60]=payload
  disk[632+10+j-2]=head
 if not eoc:root[(15+number)*32:(16+number)*32]=bytes(32)
 disk[632]=root[:512];disk[634]=root[512:1024]
 d=p/'sim/fixtures/library'/label;d.mkdir(parents=True,exist_ok=True)
 (d/'info.hex').write_text(f'{len(disk):08x}\n{min(number,8):08x}\n00000000\n')
 (d/'lbas.hex').write_text('\n'.join(f'{v:08x}' for v in disk)+'\n')
 (d/'data.hex').write_text('\n'.join(f'{v:02x}' for sec in disk.values() for v in sec)+'\n')
def run_test(name,mods,argslist):
 exe=p/'build'/f'test_{name}.vvp'
 q=subprocess.run([base+'iverilog.exe','-g2012','-s','tb_'+name,'-o',str(exe),*[str(p/'rtl'/f'{m}.v') for m in mods],str(p/'sim'/f'tb_{name}.sv')],env=env,capture_output=True,text=True)
 assert q.returncode==0,q.stdout+q.stderr
 logs=[]
 for args in argslist:
  q=subprocess.run([base+'vvp.exe',str(exe),*args],cwd=p,env=env,capture_output=True,text=True)
  out=q.stdout+q.stderr;print(out,flush=True);logs.append(out)
  assert q.returncode==0 and 'PASS' in out,out
 (p/'verification'/f'{name}.log').write_text('\n'.join(logs))
if __name__=='__main__':
 cases=[[f'+DIR=sim/fixtures/library/{label}',f'+SELECT={n}',f'+KIND={video}'] for label,video in [('music',0),('video',1)] for n in range(8)]
 cases += [['+DIR=sim/fixtures/library/eoc','+SELECT=1'],['+DIR=sim/fixtures/library/empty','+EMPTY=1']]
 run_test('library_reader',['fat32_media_stream'],cases)
 run_test('library_control',['shell_control','media_owner'],[[]])
 run_test('arcade_events',['shell_control','arcade_input','ui_state_cdc','breakout_core'],[[]])
 run_test('library_restart',['media_owner','audio_fifo'],[[]])
 run_test('sector_count',['fat32_media_stream','fat32_bmp_loader','bmp_fit_scaler','scale_divider','scale_lerp','album_line_buffer'],[[]])
 run_test('library_ui',['shell_overlay'],[[]])
 run_test('chinese_title_stream',['shell_overlay'],[[]])
