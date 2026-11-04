from pathlib import Path
import sys,struct,hashlib,tempfile,subprocess,binascii,json
p=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(p/'tools'))
from prepare_titles import encode_pack,short_identity
font=Path('C:/Windows/Fonts/simhei.ttf')
pack,report=encode_pack([(0,'唯一 邓紫棋-Let Go.wav',b'MUSIC   WAV'),(1,'我的视频(1).SAV',b'VIDEO   SAV')],font)
assert pack[:8]==b'SUKITL01' and len(pack)==4608 and 0<report['glyph_count']<=64
assert pack[2560+1]==len('唯一 邓紫棋-Let Go.wav')
assert any(b>=128 for b in pack[2564:2564+len('唯一 邓紫棋-Let Go.wav')])
for count in [0,1,63]:
 name='字'*count if count else 'A.WAV'
 data,_=encode_pack([(0,name,b'ONE     WAV')],font)
 assert data[2561]==len(name)
def fails(items):
 try:encode_pack(items,font)
 except ValueError:return
 raise AssertionError('invalid input accepted')
fails([(0,'字'*64,b'ONE     WAV')])
fails([(0,'A.WAV',f'F{i:07d}WAV'.encode()) for i in range(9)])
fails([(0,'A.WAV',b'ONE     WAV'),(0,'B.WAV',b'ONE     WAV')])
fails([(0,''.join(chr(0x4e00+i) for i in range(63)),b'ONE     WAV'),(1,'丿乀',b'TWO     SAV')])
at_limit,_=encode_pack([(0,''.join(chr(0x4e00+i) for i in range(32)),b'ONE     WAV'),
                       (1,''.join(chr(0x4e20+i) for i in range(32)),b'TWO     SAV')],font)
assert struct.unpack_from('<H',at_limit,10)[0]==64 and max(at_limit[2564:2596]+at_limit[2692:2724])==191
# The actual short-name checksum is stable and a collision is refused.
hashes={};collision=None
for i in range(100000):
 identity=f'F{i:07X}WAV'.encode();h=binascii.crc_hqx(identity,0xffff)
 if h in hashes:collision=(hashes[h],identity);break
 hashes[h]=identity
assert collision
fails([(0,'A.WAV',collision[0]),(0,'B.WAV',collision[1])])
with tempfile.TemporaryDirectory(dir=p/'build',prefix='title_tool_') as folder:
 root=Path(folder);media=root/'one.wav';media.write_bytes(b'RIFF'+bytes(56));before=hashlib.sha256(media.read_bytes()).hexdigest()
 assert short_identity(media)==b'ONE     WAV'
 cmd=[sys.executable,str(p/'tools/prepare_titles.py'),str(root)]
 r=subprocess.run(cmd,capture_output=True,encoding='utf8');assert r.returncode==0,r.stderr
 original=(root/'TITLES.BIN').read_bytes();assert len(original)==4608
 assert hashlib.sha256(media.read_bytes()).hexdigest()==before
 r=subprocess.run(cmd+['--dry-run'],capture_output=True,encoding='utf8');assert r.returncode==0
 assert (root/'TITLES.BIN').read_bytes()==original
 for i in range(8):(root/f'F{i}.WAV').write_bytes(bytes(60))
 r=subprocess.run(cmd,capture_output=True,encoding='utf8');assert r.returncode!=0
 assert (root/'TITLES.BIN').read_bytes()==original and not list(root.glob('TITLE_*.TMP'))
print('PASS title preparation: exact format/limits, Chinese/lowercase/punctuation glyphs, Windows short identity, CRC collision refusal, dry run, atomic replacement, invalid-input rollback and unchanged media bytes.')
