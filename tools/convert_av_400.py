"""Convert original video to SUKI PAL8 400x225/15 with 24k mono PCM."""
import argparse, math, os, struct, subprocess, tempfile
from pathlib import Path
from video_common import find_ffmpeg
W,H,FPS=400,225,15
PIXELS=W*H
PCM_BYTES=3200
PACKET_BYTES=94208
PAL_BYTES=512
PAD_BYTES=496
RAW_BYTES=PIXELS+1024

def command(args):
 r=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 if r.returncode:raise RuntimeError(r.stderr.decode('utf-8',errors='replace'))

def palette565(bgra):
 return b''.join(struct.pack('<H',((r>>3)<<11)|((g>>2)<<5)|(b>>3)) for b,g,r,a in struct.iter_unpack('<4B',bgra))

def demo(frame):
 # Distinct palette every frame detects stale or prematurely replaced tables.
 colors=[((i+frame*7)%32)<<11|((i*3+frame*5)%64)<<5|((i*5+frame)%32) for i in range(256)]
 indices=bytearray(((x//5+y//3+frame*11)&255) for y in range(H) for x in range(W))
 for y in range(25):
  if frame%FPS==0:indices[y*W:y*W+50]=bytes([255])*50
 colors[255]=65535
 pcm=b''.join(struct.pack('<h',int(9000*math.sin(2*math.pi*880*(frame*1600+n)/24000))) if frame%FPS<2 else b'\0\0' for n in range(1600))
 return pcm,struct.pack('<256H',*colors),indices

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('input',nargs='?');ap.add_argument('-o','--output',type=Path,default=Path('VIDEO.SAV'))
 ap.add_argument('--seconds',type=float,default=1800,help='maximum duration in seconds (default: complete clip up to 30 minutes)');ap.add_argument('--ffmpeg');ap.add_argument('--demo',action='store_true')
 args=ap.parse_args()
 if not 0<args.seconds<=1800:ap.error('--seconds must be in (0,1800]')
 if not args.demo and not args.input:ap.error('provide an input clip or --demo')
 if args.input and Path(args.input).resolve()==args.output.resolve():ap.error('input and output must differ')
 args.output.parent.mkdir(parents=True,exist_ok=True)
 silent=False
 with tempfile.TemporaryDirectory(prefix='suki_palette_',dir=args.output.parent) as tmp:
  tmp=Path(tmp);video=tmp/'video.raw';audio=tmp/'audio.raw'
  if args.demo:frames=max(1,int(args.seconds*FPS))
  else:
   ffmpeg=find_ffmpeg(args.ffmpeg)
   vf=('fps=15:start_time=0,scale=400:224:flags=lanczos:force_original_aspect_ratio=decrease:force_divisible_by=2,'
       'format=rgb24,pad=400:225:(ow-iw)/2:(oh-ih)/2:black,setsar=1,split[a][b];'
       '[a]palettegen=stats_mode=single:reserve_transparent=0[p];'
       '[b][p]paletteuse=new=1:dither=bayer:bayer_scale=3')
   base=[ffmpeg,'-v','error','-nostdin','-y','-i',args.input]
   print('1/3: Converting video. Long clips may take several minutes...',flush=True)
   command(base+['-map','0:v:0','-t',str(args.seconds),'-an','-sn','-vf',vf,'-pix_fmt','pal8','-f','rawvideo',str(video)])
   size=video.stat().st_size
   if not size or size%RAW_BYTES:raise ValueError('No complete PAL8 frames')
   frames=size//RAW_BYTES
   print(f'2/3: Converting audio for {frames/FPS:.2f} seconds...',flush=True)
   r=subprocess.run(base+['-map','0:a:0?','-t',str(frames/FPS),'-vn','-af','aresample=24000:async=1:first_pts=0,apad','-ac','1','-ar','24000','-c:a','pcm_s16le','-f','s16le',str(audio)],capture_output=True)
   if r.returncode:
    error=r.stderr.decode(errors='replace')
    if 'does not contain any stream' in error or 'does not contain any audio stream' in error:silent=True
    else:raise RuntimeError(error)
  if not 1<=frames<=27000:raise ValueError('Unsupported frame count')
  print(f'3/3: Packing {frames} frames into VIDEO.SAV...',flush=True)
  stage=tmp/'output.SAV'
  with stage.open('wb') as out:
   header=struct.pack('<8s4H3I2HI',b'SUKIPL01',W,H,FPS,5,frames,frames*PACKET_BYTES,24000,1600,16,PACKET_BYTES)
   out.write(header.ljust(512,b'\0'))
   if args.demo:
    for i in range(frames):
     pcm,pal,idx=demo(i);out.write(pcm);out.write(pal);out.write(idx);out.write(bytes(PAD_BYTES))
   else:
    with video.open('rb') as vp:
     audio_file=None if silent else audio.open('rb')
     try:
      for i in range(frames):
       raw=vp.read(RAW_BYTES)
       out.write(bytes(PCM_BYTES) if silent else audio_file.read(PCM_BYTES).ljust(PCM_BYTES,b'\0'))
       out.write(palette565(raw[PIXELS:]));out.write(raw[:PIXELS]);out.write(bytes(PAD_BYTES))
       if (i+1)%900==0:print(f'Packed {i+1}/{frames} frames ({(i+1)*100//frames}%)',flush=True)
     finally:
      if audio_file:audio_file.close()
  os.replace(stage,args.output)
 print(f'{args.output}: {frames} frames, {frames/FPS:.2f}s; 400x225 PAL8 15fps + 24kHz/16-bit mono; {args.output.stat().st_size} bytes'+('; source has no audio, silence inserted' if silent else ''))
if __name__=='__main__':main()
