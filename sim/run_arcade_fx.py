"""Run light arcade FX checks and optional full-frame previews."""
import sys
from run_library import run_test
run_test('arcade_fx',['arcade_renderer'],[[]])
if '--preview' in sys.argv:
    run_test('arcade_fx_preview',['arcade_renderer'],[[]])
