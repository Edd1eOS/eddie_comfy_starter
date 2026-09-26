@echo off
setlocal
set "REPO_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%REPO_ROOT%launcher\ComfyUIWorkbench.ps1"
endlocal
