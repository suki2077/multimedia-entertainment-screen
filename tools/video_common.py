"""Locate the bundled FFmpeg executable."""
import os
from pathlib import Path
import shutil

def find_ffmpeg(explicit):
    candidates = [explicit, Path(__file__).with_name('ffmpeg.exe'), os.environ.get('FFMPEG_EXE'), shutil.which('ffmpeg'),
                  'D:/FPGA/video_hdmi/tools/ffmpeg.exe']
    # The project's existing audio conversion runtime, if run in the workspace.
    candidates += list(Path.cwd().glob('work/audio_tools/imageio_ffmpeg/binaries/ffmpeg*.exe'))
    for item in candidates:
        if item and Path(item).is_file():
            return str(Path(item).resolve())
    raise FileNotFoundError('FFmpeg not found. Pass --ffmpeg PATH or install FFmpeg.')

