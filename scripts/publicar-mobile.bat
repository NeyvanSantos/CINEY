@echo off
setlocal
set "REPO_ROOT=%~dp0.."
pushd "%REPO_ROOT%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_release.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo A publicacao terminou com erro. Consulte a mensagem acima.
pause
popd
exit /b %RESULT%
