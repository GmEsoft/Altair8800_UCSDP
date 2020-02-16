;** Z-80(tm) DISASSEMBLER V1.10beta5 - (c) 2015-20 GmEsoft, All rights reserved. **
;
;	Sat Feb 08 10:22:17 2020
;
;	Disassembly of : CDBL.HEX
;	Equates file   : CDBL.EQU
;	Screening file : CDBL.SCR

DELAY	EQU	0682H		;some delay
ENDDST	EQU	4CE1H		;end of relocatable dest block
BUF137	EQU	4D7BH		;137-byte buffer
EBSADDR	EQU	4D7CH		;end bootstrap address
ENDSRC	EQU	0FFF5H		;end of relocatable source block


	ORG	0FF00H		;entry point: relocate bootloader to 4C00H
	DI			;no interrupt while bootloading
	LD	DE,ENDSRC	;end of relocatable source block
	LD	HL,ENDDST	;end of relocatable dest block
	;relocate loader
LRELOC	DEC	DE		;dec source ptr
	DEC	HL		;dec dest ptr
	LD	A,(DE)		;read byte from source
	LD	(HL),A		;write byte to dest
	LD	A,L		;check if 4C00H reached
	OR	A		;
	JP	NZ,LRELOC	;loop until yes
	LD	BC,DELAY	;some delay
	JP	(HL)		;exec bootloader


LORG$	DEFL	$


	ORG	4C00H		;relocate at 4C00H
ORG$	DEFL	$
	LORG	LORG$

	OUT	(22H),A		;??
	CPL			;??
	OUT	(23H),A		;??
	LD	A,2CH		;??
	OUT	(22H),A		;??
	;wait reset
LWRESET	XOR	A		;select drive 0
	OUT	(08H),A		;
	IN	A,(08H)		;read status
	AND	08H		;check if ready ??
	JP	NZ,LWRESET	;loop until ready
	LD	A,04H		;cmd=load head to drive surface
	OUT	(09H),A		;send cmd
	LD	A,01H		;cmd=step in one track
	;wait track 0
LWTRK0	OUT	(09H),A		;send cmd
	;delay loop
LDELY1	DEC	BC		;
	LD	A,B		;
	OR	C		;
	JP	NZ,LDELY1	;delay loop
	INC	C		;BC=0001H, for next timing loops
	;wait stop of movement
LWSTOP	IN	A,(08H)		;read status
	RRCA			;move head movement flag
	RRCA			;  to cy
	JP	C,LWSTOP	;wait stop of movement
	AND	10H		;check track 0 flag
	LD	A,02H		;cmd=step out one track
	JP	NZ,LWTRK0	;wait track 0
	;wait sector #15 & sector_true
LWSCT15	IN	A,(09H)		;read sector number and sector_true flag
	AND	3FH		;mask unused bits 6 and 7
	CP	1EH		;check if sector is 15 and sector_true active
	JP	NZ,LWSCT15	;loop if not
	;wait !sector_true
LWNTRUE	IN	A,(09H)		;read sector number and sector_true flag
	RRCA			;check sector_true flag
	JP	NC,LWNTRUE	;loop if still active
	;wait sector_true (next sector)
LWTRUE	IN	A,(09H)		;read sector number and sector_true flag
	RRCA			;check sector_true flag
	JP	C,LWTRUE	;wait sector_true
	AND	1FH		;get sector number (expecting 16 for 8" or 0 for 5"25)
	ADD	A,10H		;add 16 sectors
	LD	C,A		;C=number of sectors to read  (32 or 16)
	LD	H,L		;HL=0
	LD	A,03H		;2SIO1 ctrl = 3
	OUT	(10H),A		;
	LD	A,11H		;2SIO1 ctrl = 11H
	OUT	(10H),A		;
	;next sector loop
LNXTSEC	LD	A,10H		;Number of total tries: 16
	;try up to 16 times
LRETRY	LD	SP,BUF137	;137-byte buffer
	PUSH	AF		;Save retry counter
	;wait sector #(B) & sector_true
LWSECTB	IN	A,(09H)		;Get sector number and sector_true flag
	AND	3FH		;mask unused bits
	RRCA			;align sector number
	CP	B		;compare with B
	JP	NZ,LWSECTB	;wait sector #(B) & sector_true
	LD	DE,BUF137	;137-byte buffer
	LD	A,H		;Check pointer
	XOR	D		;  against bootloader address
	AND	0FEH		;H between 4CH and 4DH?
	LD	A,4FH		;Error code = 'O'
	JP	Z,ERROR		;abort with O(verrun error if not
	PUSH	HL		;save pointer
	PUSH	BC		;save sector# and sector count
	LD	BC,0080H	;B=checksum, C=block size
	;wait byte to read
LWREAD	IN	A,(08H)		;read drive status
	RLCA			;check bit 7
	JP	C,LWREAD	;loop until there is a byte to read
	IN	A,(0AH)		;read byte
	LD	(DE),A		;save to buffer
	INC	E		;increment buffer ptr
	JP	NZ,LWREAD	;loop until 137 bytes are read
	LD	E,7EH		;point to payload
	;copy 128 bytes from DE to HL
LCPY128	LD	A,(DE)		;get payload byte
	LD	(HL),A		;write to memory
	CP	(HL)		;check if write is OK
	JP	NZ,ERRMEM	;abort with M(emory write error if not
	ADD	A,B		;update checksum
	LD	B,A		;
	INC	DE		;inc buffer ptr
	INC	HL		;inc dest ptr
	DEC	C		;decr counter
	JP	NZ,LCPY128	;loop 128 times
	EX	DE,HL		;buffer ptr to HL
	LD	C,(HL)		;get stop byte (expecting 0FFH)
	INC	C		;incr stop byte (0 if OK)
	INC	HL		;incr buffer ptr
	XOR	(HL)		;Compare checksum (expecting 0)
	OR	C		;conbine with stop byte check (id.)
	POP	BC		;restore sector counter
	JP	NZ,ERRCKS	;stop/C(hecksum err => try up to 16 times
	LD	HL,(EBSADDR)	;end bootstrap address
	EX	DE,HL		;  to DE; restore dest ptr to HL
	LD	A,L		;compare dest ptr with end bootstrap address
	SUB	E		;
	LD	A,H		;
	SBC	A,D		;
	JP	NC,EXIT		;Execute loaded bootstrap if end reached
	LD	DE,LNXTSEC	;push next sector loop return address
	PUSH	DE		;
	INC	B		;bump B by 2 to next sector (interleave factor 2)
	INC	B		;Sequence is 0,2,4..30,1,3,5..31 for 8" disks
	LD	A,B		;  or 0,2,4..14,1,3,5..15 for 5"25 minidisks
	CP	C		;is sector number in C reached
	RET	C		;loop again if not
	LD	B,01H		;switch to odd sectors
	RET	Z		;loop again if sector numbers were even
	LD	A,B		;cmd=step in
	OUT	(09H),A		;send cmd
	DEC	B		;sector #0
	RET			;read next track

	;stop/C(hecksum err => try up to 16 times
ERRCKS	LD	A,04H		;cmd=load head to drive surface
	OUT	(09H),A		;send cmd
	POP	HL		;restore dest ptr to try again
	POP	AF		;restore retry counter
	DEC	A		;next retry
	JP	NZ,LRETRY	;try up to 16 times
	LD	A,43H		;error code = C)hecksum error

	DB	11H		;skip next LD A,n instruction

	;M(emory write error
ERRMEM	LD	A,4DH		;error code = M)emory write error
	;send error code in 'A'
ERROR	LD	B,A		;error code to B
	SCF			;Cy set to abort
	;clear controller & reboot (C) / halt (NC)
EXIT	LD	A,80H		;Clear drive controller
	OUT	(08H),A		;
	JP	NC,0000H	;Exec bootstrap is C not set
	EI			;enable interrupts
	LD	(0001H),HL	;store pointer to 0001-0002
	LD	A,B		;error code
	LD	(0000H),A	;store to 0000
	;send error chr to all terms
LERRCHR	OUT	(01H),A		;send to SIO
	OUT	(11H),A		;send to 2SIO1
	OUT	(05H),A		;send to ACR
	OUT	(23H),A		;send to ???
	JP	LERRCHR		;loop infinitely


	END	0FF00H

