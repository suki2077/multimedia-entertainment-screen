@echo off
setlocal
if "%~1"=="" (
 echo Drag the ORIGINAL video file onto this script.
 pause
 exit /b 1
)
echo Converting to 480x270 PAL8, 30 fps, 24 kHz mono audio.
echo Maximum single file: 18 minutes 3.8 seconds.
python "%~dp0convert_av_hq.py" "%~1" --ffmpeg "%~dp0ffmpeg.exe" -o "%~dp0..\TF_CARD\%~n1.SAV"
if errorlevel 1 (
 echo FAILED. Previous output is preserved.
 pause
 exit /b 1
)
echo SUCCESS: Copy the SAV from TF_CARD to your TF card.
echo Requires the native30 bit. This format is incompatible with the 20 fps bit.
pause
