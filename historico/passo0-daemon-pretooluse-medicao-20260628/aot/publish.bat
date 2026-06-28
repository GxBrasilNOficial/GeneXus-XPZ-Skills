@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 (echo VCVARS_FAILED & exit /b 1)
set "PATH=%PATH%;C:\Program Files (x86)\Microsoft Visual Studio\Installer"
cd /d "%~dp0"
dotnet publish -c Release -r win-x64 --nologo -v minimal
