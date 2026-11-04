from pathlib import Path
import subprocess,struct,sys,json
p=Path(__file__).resolve().parent.parent;tmp=p/'build/long_clip_test';tmp.mkdir(exist_ok=True)
ff=p/'tools/ffmpeg.exe';src=tmp/'source.mkv';out=tmp/'VIDEO.SAV';pcm=tmp/'reference.pcm'
subprocess.run([str(ff),'-v','error','-y','-f','lavfi','-i','color=c=blue:s=64x64:r=15:d=35','-f','lavfi','-i','sine=frequency=997:sample_rate=48000:duration=35','-c:v','ffv1','-c:a','pcm_s16le',str(src)],check=True)
subprocess.run([sys.executable,str(p/'tools/convert_av.py'),str(src),'--ffmpeg',str(ff),'-o',str(out)],check=True)
subprocess.run([str(ff),'-v','error','-y','-i',str(src),'-map','0:a:0','-t','35','-vn','-af','aresample=24000:async=1:first_pts=0,apad','-ac','1','-ar','24000','-c:a','pcm_s16le','-f','s16le',str(pcm)],check=True)
with out.open('rb') as f,pcm.open('rb') as r:
 h=struct.unpack('<8s4H3I2HI',f.read(36));assert h[5]==525 and h[7:]==(24000,1600,16,133632),h
 f.seek(512)
 for i in range(525):
  pkt=f.read(133632);assert len(pkt)==133632
  assert pkt[:3200]==r.read(3200),f'PCM differs at frame {i}'
 assert not f.read(1) and not r.read(1)
assert out.stat().st_size==512+525*133632
result='PASS default conversion retains complete 35-second clip (525 frames, beyond old 30-second cutoff); every PCM sample matches 24k reference; packet lengths and header verified.'
(p/'verification/long_converter.log').write_text(result+'\n');print(result)

