#!/bin/sh

# Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
# Original author: Paul Boddie <paul.boddie@biotek.uio.no>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ -e "irdata-config" ]; then
    . "$PWD/irdata-config"
elif [ -e "scripts/irdata-config" ]; then
    . 'scripts/irdata-config'
else
    . 'irdata-config'
fi

if [ "$1" = '--help' ]; then
    cat 1>&2 <<EOF
Usage: $PROGNAME <working directory> <output filename>

Read records from standard input, producing a separate file for each record in
the specified working directory, and ultimately an archive of these files with
the given output filename.
EOF
    exit 1
fi

WORKDIR=$1
OUTFILE=$2

if [ ! "$WORKDIR" ]; then
    echo "$PROGNAME: A working directory must be specified." 1>&2
    exit 1
fi

if [ ! "$OUTFILE" ]; then
    echo "$PROGNAME: An output filename must be specified." 1>&2
    exit 1
fi

if [ ! -e "$WORKDIR" ]; then
    mkdir "$WORKDIR"
fi

# Trap any unforeseen exits, removing the working directory and its files.

trap 'rm "$WORKDIR"/*.irfd ; rmdir "$WORKDIR" ; exit 1' INT TERM EXIT

# For each line...

read -r LINE
while [ "$LINE" ]; do

    # Get the record identifier and make a filename for it.
    # Then, write the record into a file with that name.

    IDENTIFIER=`echo $LINE | cut -f 1 -d '|' | sed 's/\//_/g'`
    echo $LINE > "$WORKDIR/${IDENTIFIER}.irfd"

    read -r LINE
done

cd "$WORKDIR" && jar cf "$OUTFILE" *.irfd

# Remove traps.

trap - INT TERM EXIT

# Remove the working directory and its files.

rm "$WORKDIR"/*.irfd
rmdir "$WORKDIR"
