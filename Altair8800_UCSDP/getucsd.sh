#!/bin/sh

get() {
	echo ":: Getting $2 ::"
	mkdir -p $1
	cd $1
	curl -o $2 $3
	tar -xvf $2
	cd ..
}

get_z80pack() {
	get cpmsim $1.tgz https://www.autometer.de/unix4fun/z80pack/ftp/$1.tgz
}

#system
get_z80pack ucsd-booter
get_z80pack ucsd-i4
get_z80pack ucsd-i5
get_z80pack ucsd-ii
get_z80pack ucsd-iv
get_z80pack ucsd-i5-disks
get_z80pack ucsd-i5-interp
get_z80pack ucsd-ii-disks
get_z80pack ucsd-ii-interp
get_z80pack ucsd-iv-interp

#games
get_z80pack ucsd-adventure
get_z80pack ucsd-startrek
get_z80pack ucsd-games
get_z80pack ucsd-kbdb

