"""Photo-only view regression. Run with Python/Pillow in the project environment."""
from run_library import run_test
cases=[('photo_clean',['media_controls','shell_control','player_ui','audio_wave_overlay','subtitle_overlay','shell_overlay']),('photo_clean_label',['shell_overlay']),('volume_controls',['media_controls']),('library_control',['shell_control','media_owner']),('library_switch',['library_switch','shell_control','media_controls']),('library_ui',['shell_overlay']),('chinese_title_stream',['shell_overlay'])]
for name,mods in cases:run_test(name,mods,[[]])
