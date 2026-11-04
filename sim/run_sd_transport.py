"""Real SPI transport regression. wire_pipeline is a slow full A/V simulation."""
import argparse
import os
from pathlib import Path
import subprocess

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--job', choices=['sd_multiread', 'wire_reader', 'wire_pipeline'], default='sd_multiread')
ap.add_argument('--log-name', help='optional separate log name')
ap.add_argument('--pixel-stride',type=int,default=1,help='wire pipeline RGB sample interval; timing/PCM/DE checks remain continuous')
args = ap.parse_args()
p = Path(__file__).resolve().parent.parent
env = os.environ.copy()
env['PATH'] = 'D:/FPGA/rtl_sim_tools/bin;' + env['PATH']
env['TMP'] = env['TEMP'] = 'D:/FPGA/tf_console_hdmi/build'
mods = ['spi_master', 'sd_card_cmd', 'sd_card_sec_read_write', 'sd_card_top']
benches = [p / 'sim' / f'tb_{args.job}.sv']
top = 'tb_' + args.job
if args.job != 'sd_multiread':
    mods += ['fat32_media_stream', 'av_unpacker']
    benches.insert(0, p / 'sim/sd_spi_fixture.sv')
if args.job == 'wire_pipeline':
    top = 'tb_av_pipeline'
    mods += ['mono_pair', 'audio_fifo', 'video_pcm_player', 'video_store', 'line_buffer', 'frame_video']
exe = p / 'build' / f'{args.job}.vvp'
subprocess.run(['D:/FPGA/rtl_sim_tools/bin/iverilog.exe', '-g2012', '-s', top, '-o', str(exe),
                *[str(p / 'rtl' / f'{m}.v') for m in mods], *map(str, benches)], env=env, check=True)
cases = [0, 1] if args.job == 'wire_reader' else [None]
for case in cases:
    extra = [] if case is None else ['+DIR=sim/fixtures/video/partition', f'+MULTI={case}']
    if args.job == 'wire_pipeline':extra += [f'+PIXEL_STRIDE={args.pixel_stride}']
    name = args.log_name or (args.job if case is None else f'{args.job}_{case}')
    with (p / 'verification' / f'{name}.log').open('w') as log:
        proc = subprocess.Popen(['D:/FPGA/rtl_sim_tools/bin/vvp.exe', str(exe), *extra],
                                cwd=p, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in proc.stdout:
            print(line, end='', flush=True)
            log.write(line)
            log.flush()
        if proc.wait():
            raise SystemExit(f'FAIL {name}; see verification/{name}.log')
