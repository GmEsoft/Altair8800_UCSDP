;=== Altair-8800 UCSD Pascal Primary Bootstrap  ===
;
;	Mon Feb 10 12:13:14 2020
;
;	Equates file   : DISK01BOOT.EQU
;	Screening file : DISK01BOOT.SCR

BIOSTK0	EQU	0EB00H		;BIOS dest for track 0
SECBUF	EQU	0DE00H		;Sector buffer
SECCKS	EQU	0DE84H		;Sector checksum
STACK	EQU	0DF00H		;Stack origin
BIOSTK1	EQU	0FB00H		;BIOS dest for track 1
DF080	EQU	0F080H		;-0F80H for odd sectors
BIOSTRA	EQU	0F500H		;BIOS entry point
DFFFA	EQU	0FFFAH		;-6


	ORG	0000H
	;bootstrap entry point
IPL	LD	SP,STACK	;Stack origin
	DI			;No interrupts
	XOR	A		;Select drive 0
	OUT	(08H),A		;Send select
	;wait drive ready
WREADY	IN	A,(08H)		;Get status
	AND	08H		;Is ready ?
	JP	NZ,WREADY	;Loop until yes
	LD	A,04H		;Load head
	OUT	(09H),A		;Send cmd
	JP	CKTRK0		;check that track# is 0

	;step head outwards
STEPOUT	IN	A,(08H)		;Get status
	AND	02H		;Move allowed?
	JP	NZ,STEPOUT	;Loop until yes
	LD	A,02H		;Step out
	OUT	(09H),A		;Send cmd
	;check that track# is 0
CKTRK0	IN	A,(08H)		;Get status
	AND	40H		;Check if head on track 0
	JP	NZ,STEPOUT	;step head outwards if not
	LD	BC,L0100	;C=Track 0; B-1=Sector 0
	LD	HL,BIOSTK0	;BIOS dest for track 0
	CALL	RDTRACK		;load full track in memory
	JP	INSTALL		;Jump to BIOS entry point

	;load full track in memory
RDTRACK	PUSH	BC		;Save track/sector
	PUSH	HL		;Save dest ptr
	CALL	LSECTOR		;Load sector to memory and check
	JP	NZ,IPL		;reboot if error occurred
	POP	HL		;Restore dest ptr
	LD	DE,L0100	;Bump dest ptr by 2 sectors
	ADD	HL,DE		;
	POP	BC		;Restore track/sector
	LD	A,B		;Bump sector by 2
	ADD	A,02H		;
	LD	B,A		;Save sector#
	CP	21H		;End of track ?
	JP	C,RDTRACK	;Continue if not
	SUB	1FH		;Else switch to odd tracks
	LD	DE,DF080	;-0F80H for odd sectors
	ADD	HL,DE		;Offset dest ptr to load odd sectors
	CP	03H		;Done with odd sectors ?
	LD	B,A		;Save sector#
	JP	NZ,RDTRACK	;load full track in memory
	RET			;Done reading track

	;Load sector to memory and check (NZ on error)
LSECTOR	PUSH	BC		;Save track/sector
	PUSH	HL		;Save dest ptr
	CALL	RSECTOR		;read sector B-1 to buffer
	LD	DE,DFFFA	;end sector -6: point to stop byte
	ADD	HL,DE		;
	INC	(HL)		;Check that stop is 0FFh
	POP	BC		;Restore dest ptr to BC
	POP	DE		;Restore track/sector to DE
	RET	NZ		;Abort if stop is not 0FFh
	LD	HL,SECBUF	;Sector buffer ptr
	LD	A,(HL)		;Get track number
	AND	7FH		;mask high bit
	CP	E		;Compare with track# in E
	RET	NZ		;Abort if not same
	INC	HL		;Bump sector ptr to payload
	INC	HL		;
	INC	HL		;
	CALL	MOVDATA		;Move data from buf to mem @BC; cks to A
	LD	HL,SECCKS	;Sector checksum
	CP	(HL)		;Compare with checksum in buffer
	RET			;Done with sector loading

	;read sector B-1 to buffer (Z on exit)
RSECTOR	DEC	B		;Physical sector #
	CALL	WSECTOR		;wait sector# in B and sector_true
	LD	C,89H		;Sector buffer length (137)
	LD	HL,SECBUF	;Sector buffer ptr
	;wait read byte
WREAD	IN	A,(08H)		;Get status
	OR	A		;Byte ready to read?
	JP	M,WREAD		;Loop until yes
	IN	A,(0AH)		;Read byte
	LD	(HL),A		;Store in buffer
	INC	HL		;Inc buffer ptr
	DEC	C		;Decr byte counter
	JP	Z,L00B2		;Exit when all bytes read
	DEC	C		;Decr byte counter again
	NOP			;Micro delay
	IN	A,(0AH)		;Read next byte
	LD	(HL),A		;Store in buffer
	INC	HL		;Bump buffer ptr
	JP	NZ,WREAD	;wait read byte
L00B2	XOR	A		;Read successful, exit with Z
	RET			;Done reading sector

	;wait physical sector# in B and sector_true
WSECTOR	CALL	HDLOAD		;Load head to surface
LWSECT	IN	A,(09H)		;Get sector# and sector_true from drive
	RRA			;Check sector_true
	JP	C,LWSECT	;Loop while !sector_true
	AND	1FH		;Get physical sector #
	CP	B		;Compare with B
	JP	NZ,LWSECT	;Loop until same
	RET			;Done waiting

	;Move data from buf to mem @BC; cks to A
MOVDATA	LD	DE,0080H	;D=Checksum, E=Number of bytes
LMVDAT	LD	A,(HL)		;Get byte from buffer
	LD	(BC),A		;Write to memory
	ADD	A,D		;Update checksum
	LD	D,A		;
	INC	HL		;Bump buffer ptr
	INC	BC		;Bump memory ptr
	DEC	E		;Count byte
	JP	NZ,LMVDAT	;Loop until all bytes moved
	RET			;Exit with checksum in A

	;Load head to surface
HDLOAD	IN	A,(08H)		;Get status
	AND	04H		;Check head loaded
	RET	Z		;Exit if yes
	LD	A,04H		;Load head
	OUT	(09H),A		;Send cmd
	RET			;Done

	;Install CBIOS and secondary bootstrap
INSTALL	LD	HL,0EC80H
	LD	DE,8200H
	LD	BC,0800H
	CALL	LDIR80
	LD	HL,(CBIOS+13)
	LD	(CONOUT1+1),HL
	LD	(CONOUT2+1),HL
	LD	HL,0FA38H	;SCTRTBL=CP/M Sector Translation table (XLT)
	LD	(CBIOS+13),HL
	EX	DE,HL
	LD	HL,CONOUT1
	LD	BC,CONOUTE-CONOUT1
	CALL	LDIR80
	JP	0EB80H

LDIR80	LD	A,(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC
	LD	A,B
	OR	C
	JP	NZ,LDIR80
	RET

CONOUT1	CALL	$-$
;	HALT
	CP	1BH
	RET	NZ
	LD	C,'['
CONOUT2	JP	$-$
CONOUTE	EQU	$

	DC	0100H-$,0	;Filler

	;0EB80H init
OFFSET	EQU	0EB80H-$

BOOT	EQU	8200H		; SECONDARY BOOTSTRAP LOADED HERE
MSIZE	EQU	64		; MEMORY SIZE FOR ASSEMBLY
BIAS	EQU	(MSIZE*1024)-02000H
CBIOS	EQU	1500H+BIAS	; ORIGIN POINT
CPMB	EQU	-0100H+BIAS	; BASE OF CCP
;SECNUM	EQU	16		; SECONDARY BOOTSTRAP IS 16 SECTORS LONG
;SECSEC	EQU	3		; SECONDARY BOOTSTRAP ON THIS SECTOR
;BIOSNUM	EQU	8		; CBIOS IS 8 SECTORS LONG
;BIOSSEC	EQU	19		; CBIOS IS ON THIS SECTOR

;	ORG	STARTING$ADDRESS	; WHATEVER IS RIGHT FOR YOUR SYSTEM

	.8080
PBOOT	LXI	H,CBIOS		; CBIOS GOES HERE
	SPHL			; RESET THE STACK
;	LXI	D,(BIOSNUM SHL 8)+BIOSSEC ; D - # OF SECTORS TO READ
;				; E - STARTING SECTOR
;	CALL	READIT		; READ IN CBIOS
;	LXI	H,BOOT		; LOAD BOOT BASE ADDRESS
;	LXI	D,(SECNUM SHL 8)+SECSEC ;D - # OF SECTORS TO READ
;				; E - STARTING SECTOR
;	CALL	READIT		; READ IN SECONDARY BOOTSTRAP

	LXI	H,128		; MAXIMUM NUMBER OF BYTES PER SECTOR
	PUSH	H
	LXI	H,32		; MAXIMUM NUMBER OF SECTORS IN TABLE
	PUSH	H
	LXI	H,0		; TRACK-TO-TRACK SKEW
	PUSH	H
	LXI	H,1		; FIRST INTERLEAVED TRACK
	PUSH	H
	LXI	H,1		; 2:1 INTERLEAVING
	PUSH	H
	LXI	H,128		; BYTES PER SECTOR
	PUSH	H
	LXI	H,32		; SECTORS PER TRACK
	PUSH	H
	LXI	H,77		; TRACKS PER DISK
	PUSH	H
	LXI	H,CBIOS-2	; TOP OF MEMORY (MUST BE WORD BOUNDARY)
	PUSH	H
	LXI	H,0100H		; BOTTOM OF MEMORY
	PUSH	H
	LXI	D,CBIOS+3	; START OF THE SBIOS (JMP WBOOT)
	PUSH	D
	PUSH	H		; STARTING ADDRESS OF INTERPRETER
	MVI	A,0C3H		; PUT IN JMP TO SECONDARY BOOTSTRAP
	STA	CPMB
	STA	CPMB+3
	LXI	H,BOOT1+OFFSET
	SHLD	CPMB+1
	SHLD	CPMB+4
;	LXI	H,BOOTMSG
;	CALL	OUTMSG
	JMP	CBIOS		; ENTER COLD BOOT

	.Z80
BOOT1	LD	HL,BOOTMSG+OFFSET
	LD	DE,BOOT
	PUSH	DE
OUTMSG	LD	A,(HL)
	CP	'$'
	RET	Z
	LD	C,A
	CALL	CBIOS+12	;CONOUT
	INC	HL
	JP	OUTMSG+OFFSET

BOOTMSG	DB	13,10,'BOOTING TO UCSD PASCAL',13,10,'$'

	DC	0180H-$,0	;Filler

L0100	EQU	0100H		;Track 0, Sector 1 (phys sector 0)
L0101	EQU	0101H		;Track 1, Sector 1 (phys sector 0)

	END	IPL

