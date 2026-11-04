"""Run with a Python providing Pillow. Native Icarus paths follow run_library."""
from pathlib import Path
import runpy,json,sys
from run_library import run_test
p=Path(__file__).resolve().parent
for script in ['test_prepare_titles.py','make_dynamic_title_fixtures.py','make_title_prefetch_fixture.py','make_fmt_validation_fixtures.py','make_album20_fixtures.py']:
    runpy.run_path(str(p/script),run_name='__main__')
cases=[['+DIR=sim/fixtures/dynamic_titles/good','+KIND='+str(k),'+SELECT='+str(n)] for k in [0,1] for n in [0,7]]
cases += [['+DIR=sim/fixtures/dynamic_titles/'+v,'+KIND='+str(k),'+COMMIT=0'] for v in ['badmagic','badfat','absent','badsize'] for k in [0,1]]
cases += [['+DIR=sim/fixtures/dynamic_titles/badcode','+KIND=1','+COMMIT=0']]
run_test('dynamic_title_reader',['fat32_media_stream'],cases)
run_test('title_prefetch',['fat32_media_stream'],[['+DIR=sim/fixtures/title_prefetch','+KIND=1']])
run_test('dynamic_title_ui',['shell_overlay'],[[]])
run_test('fmt_validation',['fat32_media_stream'],[['+DIR=sim/fixtures/fmt_validation/'+str(i)] for i in list(range(16))+['riff_small','riff_large','riff_wrap']] +
    [['+DIR=sim/fixtures/fmt_validation/'+s,'+ERROR=0'] for s in ['extra','junk','trailing']])
run_test('album20_reader',['fat32_bmp_loader','bmp_fit_scaler','scale_divider','scale_lerp','album_line_buffer'],
    [['+DIR=sim/fixtures/album20/'+str(i)] for i in [0,1,4,20,21]])
for test in ['cache_control','album20_control','album20_tagged']:
    run_test(test,['cache_album_control'],[[]])
for test,mods in [('breakout_equivalence',['breakout_core','../sim/breakout_reference']),
    ('breakout',['breakout_core']),('arcade_playthrough',['breakout_core']),
    ('arcade_events',['shell_control','arcade_input','ui_state_cdc','breakout_core']),
    ('runner_menu',['breakout_core','runner_core'])]:
    run_test(test,mods,[[]])
if '--preview' in sys.argv:run_test('dynamic_title_preview',['shell_overlay'],[[]])
if '--music' in sys.argv:
    runpy.run_path(str(p/'make_title_music_fixture.py'),run_name='__main__')
    count=json.loads((p/'fixtures/title_music/meta.json').read_text())['count']
    run_test('title_music',['fat32_bmp_loader','bmp_fit_scaler','scale_divider','scale_lerp',
        'album_line_buffer','fat32_media_stream','sd_read_arbiter','audio_fifo','pcm_player'],[['+COUNT='+str(count)]])
