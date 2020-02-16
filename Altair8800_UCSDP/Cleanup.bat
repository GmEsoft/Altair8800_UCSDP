@echo off
call :del *.dasm
call :del *.prn
call :del *.obj
call :del *.lst
call :del *.img
call :del *.map
call :del *.new
call :del *.tst
call :del *.bin
call :del *.obj
call :del DISK2?.DSK
call :del DISK3?.DSK
call :del *Disk.exe
call :rmdir build
call :rmdir zmac
call :rmdir cpmsim
goto :eof

:del
if exist %1 del %1
goto :eof

:rmdir
if exist %1 rmdir /S /Q %1
goto :eof
