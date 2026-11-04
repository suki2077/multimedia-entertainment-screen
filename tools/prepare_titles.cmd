@echo off
setlocal
set "TITLE_PY=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%TITLE_PY%" set "TITLE_PY=python"
"%TITLE_PY%" "%~dp0prepare_titles.py" %*
pause
