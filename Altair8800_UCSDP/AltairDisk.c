#include <stdio.h>
#include <io.h>
#include <ctype.h>
#include <stddef.h>
#include <string.h>

#include <fcntl.h>    // O_RDWR...
#include <sys/stat.h> // S_IWRITE

#define ALTAIR_DISK "Altair 8800 Disk Image Converter V0.1 for Altair-Duino, (C) 2020 by GmEsoft"

typedef unsigned int uint32_t;

void help()
{
	puts(
		"AltairDisk -A|-C|-X -I:infile [-O:outfile]\n"
		"   -A          Analyze\n"
		"   -C          Create\n"
		"   -X          Extract\n"
		"   -I:infile   Input image file\n"
		"   -O:outfile  Output image file\n"
		"   -B:size     Bootstrap Size\n"
	);
}

#define SEC_LEN 137

/*******************************************************

				Altair 88-DCDD Disk formats
				===========================

Size	Type-1 tracks	Type-2 tracks	Sectors
-----------------------------------------------
8"		0-5				6-76			32 (0-31)
5"25	0-11			12-35			16 (0-15)

Type-1 tracks
-------------
Byte	Use
0		Track number + 0x80
1-2		16-bit addr of the end of the bootloader
3-130	128 byte data payload
131		Stop byte 0xFF
132		Checksum (sum of the 128 byte payload)
133-136	Ignored

Type-2 tracks
-------------
Byte	Use
0		Track number + 0x80
1		Sector number
2-3		Not used, but in checksum
4		Checksum (bytes 2-134, not including byte 4)
5-6		Not used, but in checksum
7-134	128 byte data payload
135		Stop byte 0xFF
136		Stop byte 0x00

*******************************************************/

unsigned char buf[SEC_LEN];

int trk=127, sec=127, cks, i;
int seccks, secstop1, secstop2;
int secaddr=0x100, secusr1;
int sectype;
unsigned char *payload;
int numtrks=0, numsecs=0;
int nbytes;

void analyze_sector()
{
	++sec;

	if ( trk != ( buf[0] & 0x7F ) )
	{
		trk = buf[0] & 0x7F;
		sec = 0;
	}

	cks = 0;

	if ( buf[131] == 0xFF && buf[135] != 0xFF )
	{
		sectype = 1;
		secaddr = buf[1] | ( buf[2] << 8 );
		secusr1 = 0;
		for ( i=3; i<=130; ++i )
		{
			cks += buf[i];
		}
		secstop1 = buf[131];
		secstop2 = 0;
		seccks = buf[132];
		payload = buf+3;
	}
	else
	{
		sectype = 2;
		sec = buf[1];
		secaddr = buf[2] | ( buf[3] << 8 ); // not used...
		seccks = buf[4];
		secusr1 = buf[5] | ( buf[6] << 8 ); // not used
		cks = -seccks;
		for ( i=2; i<=134; ++i )
		{
			cks += buf[i];
		}
		secstop1 = buf[135];
		secstop2 = buf[136];
		payload = buf+7;
	}

	cks &= 0xFF;

	if ( trk < 127 )
	{
		if ( numtrks < trk+1 ) numtrks = trk+1;
		if ( numsecs < sec+1 ) numsecs = sec+1;
	}
}

void analyze( int infile )
{

	lseek( infile, 0, SEEK_SET );

	while ( 1 )
	{
		nbytes = read( infile, buf, SEC_LEN );

		if ( nbytes < SEC_LEN )
		{
			break;
		}

		analyze_sector();

		if ( trk<127 )
		{
			printf( "T:%02d S:%02d Ty:%d A:%04X U:%04X S1:%02X S2:%02X Cks:%02X(%02X) ",
					trk, sec, sectype, secaddr, secusr1, secstop1, secstop2, seccks, cks );
			if ( secstop1 != 0xFF )
				printf( "Bad Stop 1\n" );
			else if ( secstop2 != 0x00 )
				printf( "Bad Stop 2\n" );
			else if ( cks != seccks )
				printf( "Bad Checksum\n" );
			else
				printf( "OK\n" );
		}
		else
		{
			printf( "No data\n" );
		}
	}

	printf ( "Tracks:%d Sectors:%d\n", numtrks, numsecs );
}

void extract( int infile, int outfile )
{
	lseek( infile, 0, SEEK_SET );

	while ( 1 )
	{
		nbytes = read( infile, buf, SEC_LEN );

		if ( nbytes < SEC_LEN )
		{
			break;
		}

		analyze_sector();
	}

	printf ( "Tracks:%d Sectors:%d\n", numtrks, numsecs );

	lseek( infile, 0, SEEK_SET );

	while ( 1 )
	{
		nbytes = read( infile, buf, SEC_LEN );

		if ( nbytes < SEC_LEN )
		{
			break;
		}

		analyze_sector();

		if ( trk < 127 )
		{
			if ( sec == 0 )
				printf( "\nT:%02d S", trk );
			printf( ":%02d", sec );
			lseek( outfile, 128 * ( trk * numsecs + sec ), SEEK_SET );
			write( outfile, payload, 128 );
		}
	}
	printf( "\n" );
}

void create( int infile, int outfile )
{
	int size;
	int type2;
	int interl;
	int ncks;

	size = lseek( infile, 0, SEEK_END );

	if ( size > 100000 )
	{
		numtrks = 77;
		numsecs = 32;
		type2 = 6;
		interl = 16;
	}
	else
	{
		numtrks = 35;
		numsecs = 16;
		type2 = 12;
		interl = 0;
	}

	//secaddr = 0X0100;

	printf ( "Tracks:%d Sectors:%d\n", numtrks, numsecs );

	lseek( infile, 0, SEEK_SET );

	for ( trk = 0; trk < numtrks; ++trk )
	{
		for ( sec = 0; sec < numsecs; ++sec )
		{
			memset( buf, 0, SEC_LEN );
			buf[0] = trk | 0x80;

			if ( trk < type2 )
			{
				buf[1] = secaddr & 0xFF;
				buf[2] = secaddr >> 8;
				buf[131] = 0xFF;
				lseek( outfile, ( trk * numsecs + sec ) * SEC_LEN, SEEK_SET );
				payload = buf + 3;
				ncks = 132;
			}
			else
			{
				buf[1] = sec;
				buf[135] = 0xFF;
				lseek( outfile, ( trk * numsecs + ( sec ^ ( ( sec & 1 ) ? interl : 0 ) ) ) * SEC_LEN, SEEK_SET );
				payload = buf + 7;
				ncks = 4;
			}

			read( infile, payload, 128 );

			cks = 0;
			for ( i=0; i<128; ++i )
			{
				cks += payload[i];
			}

			buf[ncks] = cks & 0xFF;

			write( outfile, buf, SEC_LEN );
		}
	}

	printf( "\n" );
}

int main( int argc, char* argv[] )
{
	int infile=0, outfile=0;

	int	i;

	char command = 'A';

	puts( ALTAIR_DISK "\n" );

	for ( i=1; i<argc; ++i )
	{
		char *s = argv[i];
		char c = 0;

		//puts(s);
		if ( *s == '-' )
			++s;
		switch ( toupper( *s ) )
		{
		case 'A':
		case 'C':
		case 'X':
			command = toupper( *s );
			break;
		case 'I':
			++s;
			if ( *s == ':' )
				++s;
			printf( "Reading: %s\n", s );
			infile = open( (const char *)s, _O_RDONLY | _O_BINARY, _S_IREAD );
			break;
		case 'O':
			++s;
			if ( *s == ':' )
				++s;
			printf( "Creating: %s\n", s );
			outfile = open( s, _O_CREAT | _O_TRUNC | _O_RDWR | _O_BINARY, _S_IWRITE );
			break;
		case 'B':
			++s;
			if ( *s == ':' )
				++s;
			sscanf( s, "%X", &secaddr );
			break;
		case '?':
			help();
			return 0;
		default:
			printf( "Unrecognized switch: -%s\n", s );
			printf( "AltairDisk -? for help.\n" );
			return 1;
		}

		if ( errno )
		{
			puts( strerror( errno ) );
			return 1;
		}
	}


	switch ( command )
	{
	case 'A':
		analyze( infile );
		break;
	case 'C':
		create( infile, outfile );
		break;
	case 'X':
		extract( infile, outfile );
		break;
	}

	if ( infile )
		close( infile );

	if ( outfile )
		close( outfile );


	return 0;
}
