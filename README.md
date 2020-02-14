Altair8800_UCSDP
================

Port of UCSD p-System IV to Altair8800 Floppies
-----------------------------------------------

The goal of this project is to adapt an existing UCSD Pascal IV system to 8" Altair-format floppy disks
so it can be booted from the standard CP/M bootloader ROM (CDBL on Altair-Duino).

The project consists in:


BOOT20CDBL: 
-----------
The Primary Bootstrap, loading and starting the CP/M BIOS and the UCSD Secondary Bootstrap. 
The Primary Bootstrap is adapted from the AltairDuino CP/M disk boot sectors 0 and 2 that are loaded by
the CDBL ROM. Some code has beed added to move the UCSD Secondary Bootstrap to its effective location
at 8200H, and to patch the CBIOS so CONOUT can correctly handle the ANSI Escape sequences by emitting
a '<left bracket'> to 
Some additional has beed added to 
The CP/M BIOS is extracted as is from the AltairDuino CP/M DISK01.DSK disk image. 
