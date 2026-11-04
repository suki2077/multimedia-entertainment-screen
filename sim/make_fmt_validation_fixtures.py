from pathlib import Path
import struct
p=Path(__file__).resolve().parent.parent;src=p/'sim/fixtures/dynamic_titles/good'
lbas=[int(v,16) for v in (src/'lbas.hex').read_text().split()];raw=bytes.fromhex((src/'data.hex').read_text())
base={n:bytearray(raw[i*512:(i+1)*512]) for i,n in enumerate(lbas)}
for name in [str(i) for i in range(16)]+['extra','junk','trailing','riff_small','riff_large','riff_wrap']:
 disk={n:bytearray(v) for n,v in base.items()};head=disk[730];original=bytes(head[:60]);size=60
 if name=='extra':
  data=bytearray(original[:36]+b'\x99\x77'+original[36:]);size=62;struct.pack_into('<I',data,4,54);struct.pack_into('<I',data,16,18);head[:62]=data
 elif name=='junk':
  data=bytearray(original[:12]+b'JUNK'+struct.pack('<I',1)+b'x\x00'+original[12:]);size=70;struct.pack_into('<I',data,4,62);head[:70]=data
 elif name=='trailing':size=62
 elif name=='riff_small':struct.pack_into('<I',head,4,35)
 elif name=='riff_large':struct.pack_into('<I',head,4,53)
 elif name=='riff_wrap':struct.pack_into('<I',head,4,0xffffffff)
 else:head[20+int(name)]^=1
 struct.pack_into('<I',disk[632],508,size)
 out=p/'sim/fixtures/fmt_validation'/name;out.mkdir(parents=True,exist_ok=True)
 (out/'info.hex').write_text(f'{len(disk):08x}\n');(out/'lbas.hex').write_text(''.join(f'{n:08x}\n' for n in disk));(out/'data.hex').write_text(''.join(f'{v:02x}\n' for sec in disk.values() for v in sec))
s=(p/'sim/tb_dynamic_title_reader.sv').read_text().replace('tb_dynamic_title_reader','tb_fmt_validation')
s=s.replace('integer kind=0,selected=0,', 'integer error_expected=1,kind=0,selected=0,')
s=s.replace('if(failed)$fatal(1,"media failure %h state%d",err,d.state);', '''if(failed)begin
   if(!error_expected || err!=6 || samples!=0 || commits!=1)$fatal(1,"format validation incorrect err%h",err);
   $display("PASS streaming PCM format rejects changed format byte, no audio emitted, titles retained");$finish;
  end''')
s=s.replace('if(samples==4)begin','if(samples==4)begin\n    if(error_expected)$fatal(1,"corrupted PCM format accepted");')
s=s.replace('n=$value$plusargs("KIND=%d",kind);','n=$value$plusargs("ERROR=%d",error_expected);n=$value$plusargs("KIND=%d",kind);')
(p/'sim/tb_fmt_validation.sv').write_text(s)
print('Prepared all16 invalid PCM bytes, extended fmt and odd JUNK valid fixtures.')
