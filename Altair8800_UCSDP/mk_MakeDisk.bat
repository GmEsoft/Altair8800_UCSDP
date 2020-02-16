@echo off
call "C:\Program Files\Microsoft Visual Studio 8\VC\bin\vcvars32.bat"
cl MakeDisk.c
if errorlevel 1 pause && exit /B %ERRORLEVEL%
