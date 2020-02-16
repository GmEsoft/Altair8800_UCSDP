@echo off

set CPM_DISK=DISK01
set UCSD_DIR=cpmsim/disks/library

echo :: Building tools ::
if not exist AltairDisk.exe call mk_AltairDisk
if not exist MakeDisk.exe call mk_MakeDisk


echo :: Getting ZMAC ::

set ZMAC=zmac\zmac.exe
if not exist %ZMAC% getzmac.sh

echo :: Assembling primary bootstrap ::

%ZMAC% DISK20BOOT.asm --od build --oo cim,lst -c -s -g
if errorlevel 1 pause && goto :eof

echo :: Converting DISK01 to usable format ::

if not exist %CPM_DISK%.DSK (
	echo !! %CPM_DISK%.DSK not found -- please copy it from the Altair-Duino SD card !!
	pause
	exit /B 1
)

AltairDisk -A -I:%CPM_DISK%.DSK>%CPM_DISK%.LST
AltairDisk -X -I:%CPM_DISK%.DSK -O:%CPM_DISK%.IMG>%CPM_DISK%.MAP

echo :: Getting UCSD disk images ::

if not exist %UCSD_DIR:/=\%\ucsd-*.dsk getucsd.sh

echo :: MAKING DISKS ::

call :makedisk DISK20 ucsd-iv-1		1 0
call :makedisk DISK21 ucsd-iv-2		1 0
call :makedisk DISK22 ucsd-iv-interp	1 0
call :makedisk DISK23 ucsd-games	2 6
call :makedisk DISK24 ucsd-advx		2 6
call :makedisk DISK25 ucsd-advsrc	2 6
call :makedisk DISK26 ucsd-startrek	1 0
call :makedisk DISK27 ucsd-kbdbx	2 6
call :makedisk DISK28 ucsd-kbdb		2 6

call :makedisk DISK30 ucsd-i4-1		2 8
call :makedisk DISK31 ucsd-i5-1		2 6
call :makedisk DISK32 ucsd-i5-2		2 6
call :makedisk DISK33 ucsd-i5-interp	2 6
call :makedisk DISK34 ucsd-ii-1		2 6
call :makedisk DISK35 ucsd-ii-2		2 6
call :makedisk DISK36 ucsd-ii-interp	2 6

goto :eof


:makedisk
echo :: Creating disk "%1" from UCSD-P disk "%2" (interleave=%3 skew=%4)
set OUTFILE=%1
set UCSDDISK=%UCSD_DIR%/%2.dsk

if not exist %UCSDDISK% (
	echo !! %UCSDDISK% NOT FOUND !!
	pause
	exit /B 1
)

makedisk -L:128 -SO:32 -M:%OUTFILE%.IMG ^
	-I:%UCSDDISK% -SI:26 -XI:%3 -KI:%4 -F:2 -T:18 -D:3 -F:T1 -T:T77 -D:T1 -P:T77 ^
	-I:build/DISK20BOOT.CIM -SI:2 -XI:1 -KI:0 -F:0 -T:1 -D:0 -F:1 -T:2 -D:2 -F:2 -T:3 -D:1 ^
	-I:%CPM_DISK%.IMG -SI:32 -XI:1 -KI:0 -F:47 -T:59 -D:20

AltairDisk -C -I:%OUTFILE%.IMG -O:%OUTFILE%.DSK

AltairDisk -A -I:%OUTFILE%.DSK>%OUTFILE%.LST

goto :eof
