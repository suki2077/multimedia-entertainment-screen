"""Current runner/20-photo verification. Run from any working directory.

Requires Icarus at D:/FPGA/rtl_sim_tools/bin. The full-frame store and
concurrent music tests take several minutes. Fixtures are synthetic FAT32;
the reader test checks catalogues and first pixel groups, while the store
test independently checks complete frames and SDRAM boundaries.
"""
from pathlib import Path
import json
import runpy
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_library import run_test

runpy.run_path(str(HERE / 'make_album20_fixtures.py'), run_name='__main__')
run_test('runner_slide', ['runner_core'], [[]])
run_test('album20_control', ['cache_album_control'], [[]])
run_test('album20_tagged', ['cache_album_control'], [[]])
run_test('album20_reader', ['fat32_bmp_loader', 'bmp_fit_scaler',
    'scale_divider', 'scale_lerp', 'album_line_buffer'],
    [['+DIR=sim/fixtures/album20/' + str(n)] for n in [0, 1, 4, 20, 21]])
run_test('album20_store', ['frame_store_cached'], [[]])
run_test('album20_ui', ['player_ui', 'shell_overlay'], [[]])
run_test('runner_slide_preview', ['arcade_renderer'], [[]])
count = json.loads((HERE / 'fixtures/shared/meta.json').read_text())['count']
run_test('album20_music', ['fat32_bmp_loader', 'bmp_fit_scaler',
    'scale_divider', 'scale_lerp', 'album_line_buffer', 'fat32_media_stream',
    'sd_read_arbiter', 'audio_fifo', 'pcm_player'], [['+COUNT=' + str(count)]])
print('PASS runner and 20-photo suite; board acceptance remains required.')
