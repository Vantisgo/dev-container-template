@echo off
for /f "tokens=1,* delims==" %%a in ('findstr /b "GIT_BASH=" "%~dp0..\.env"') do set "GIT_BASH=%%~b"
%GIT_BASH% "%~dp0devup.sh" %*
