@echo off
call "C:\Program Files\Microsoft Visual Studio 8\VC\bin\vcvars32.bat"
cl AltairDisk.c
if errorlevel 1 pause && exit /B %ERRORLEVEL%
