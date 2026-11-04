"""Build a card-specific monochrome CJK dictionary and filename index.

Read-only media scan; only TITLES.BIN and TITLES_REPORT.json are replaced.
On Windows, GetShortPathNameW supplies the FAT 8.3 identity, so directory
ordering does not need to match Python's enumeration order. Duplicate CRC16
identities are rejected before writing any output.
"""
from pathlib import Path
import argparse,binascii,ctypes,json,os,struct,tempfile

def short_identity(path):
    name=path.name
    encoding='ascii'
    if os.name=='nt':
        api=ctypes.windll.kernel32
        buf=ctypes.create_unicode_buffer(32768)
        if not api.GetShortPathNameW(str(path.resolve()),buf,len(buf)):
            raise ValueError('Cannot read FAT short filename: '+str(path))
        name=Path(buf.value).name
        encoding='cp'+str(api.GetOEMCP())
    stem,sep,ext=name.rpartition('.')
    if not sep:stem,ext=name,''
    try:a=stem.upper().encode(encoding);b=ext.upper().encode(encoding)
    except UnicodeError as e:raise ValueError('Unsupported OEM short name: '+name) from e
    if not (1<=len(a)<=8 and 1<=len(b)<=3):
        raise ValueError('No usable 8.3 alias for '+path.name+'; run this tool on the FAT32 card itself.')
    result=a.ljust(8,b' ')+b.ljust(3,b' ')
    return (b'\x05'+result[1:]) if result[0]==0xe5 else result

def encode_pack(items,font_path):
    from PIL import Image,ImageDraw,ImageFont
    if len(items)>16:raise ValueError('At most 8 music and 8 video files are supported.')
    for kind in [0,1]:
        if sum(k==kind for k,_,_ in items)>8:
            raise ValueError('More than 8 '+('music' if kind==0 else 'video')+' files. Move extra files out of the root folder first.')
    seen={}
    for kind,name,identity in items:
        if len(name)>63:raise ValueError('Filename exceeds 63 characters: '+name)
        if any(ord(c)<32 or ord(c)==127 for c in name):raise ValueError('Control character in '+name)
        checksum=binascii.crc_hqx(identity,0xffff)
        key=(kind,checksum)
        if key in seen:raise ValueError('Short-name CRC collision: '+name+' / '+seen[key]+'. Rename one file and retry.')
        seen[key]=name
    fast_ascii=set('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ._')
    chars=sorted({c for _,name,_ in items for c in name if c not in fast_ascii})
    if len(chars)>64:raise ValueError(f'{len(chars)} custom characters (Chinese, lowercase or punctuation); maximum is64. Shorten filenames and retry.')
    codes={ch:128+i for i,ch in enumerate(chars)}
    font=ImageFont.truetype(str(font_path),16)
    glyphs=bytearray(2048)
    for index,ch in enumerate(chars):
        img=Image.new('L',(16,16));draw=ImageDraw.Draw(img)
        l,t,r,b=draw.textbbox((0,0),ch,font=font)
        draw.text(((16-r+l)//2-l,(16-b+t)//2-t),ch,font=font,fill=255)
        if not img.getbbox():raise ValueError('Font has no visible glyph for '+repr(ch))
        for y in range(16):
            bits=sum((1<<(15-x)) for x in range(16) if img.getpixel((x,y))>=112)
            struct.pack_into('<H',glyphs,(index*16+y)*2,bits)
    header=bytearray(512);header[:8]=b'SUKITL01'
    struct.pack_into('<4HI',header,8,1,len(chars),128,16,4096)
    records=bytearray(2048)
    for index in range(16):records[index*128]=255
    mapping=[]
    for i,(kind,name,identity) in enumerate(items):
        rec=memoryview(records)[i*128:(i+1)*128]
        checksum=binascii.crc_hqx(identity,0xffff)
        struct.pack_into('<BBH',rec,0,kind,len(name),checksum)
        rec[4:4+len(name)]=bytes(ord(c) if c in fast_ascii else codes[c] for c in name)
        mapping.append(dict(type='video' if kind else 'music',filename=name,
            short_name_hex=identity.hex(),crc16=f'{checksum:04x}',characters=len(name)))
    payload=bytes(header+glyphs+records)
    assert len(payload)==4608
    return payload,dict(format='SUKITL01',glyph_count=len(chars),maximum_glyphs=64,
        maximum_title_characters=63,files=mapping)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',nargs='?',help='FAT32 TF card root, for example F:\\')
    parser.add_argument('--font',type=Path,default=Path('C:/Windows/Fonts/simhei.ttf'))
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    root=Path(args.root or input('TF card root (example F:\\): ').strip().strip('"')).resolve()
    if not root.is_dir():parser.error('Folder does not exist: '+str(root))
    items=[]
    for p in root.iterdir():
        kind=0 if p.suffix.upper()=='.WAV' else 1 if p.suffix.upper()=='.SAV' else -1
        if kind<0 or not p.is_file():continue
        if p.stat().st_size<(44 if kind==0 else 134144):continue
        items.append((kind,p.name,short_identity(p)))
    if not items:parser.error('No eligible WAV or SAV files in this folder.')
    data,report=encode_pack(items,args.font)
    report['root']=str(root)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if not args.dry_run:
        # Validate completely before atomically replacing the old metadata file.
        handle,tmp=tempfile.mkstemp(prefix='TITLE_',suffix='.TMP',dir=root)
        try:
            with os.fdopen(handle,'wb') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
            os.replace(tmp,root/'TITLES.BIN')
        finally:
            if Path(tmp).exists():Path(tmp).unlink()
        (root/'TITLES_REPORT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        print('SUCCESS: TITLES.BIN generated; media files were not changed. Safely eject the card and restart the board.')

if __name__=='__main__':
    try:main()
    except (ValueError,OSError,ImportError) as e:raise SystemExit('ERROR: '+str(e))
