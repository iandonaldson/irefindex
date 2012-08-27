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
Usage: $PROGNAME <filename> <output directory> <output prefix>

Process the given filename, typically rigAttributes.irfi or rogAttributes.irfi,
making a collection of individual index files in the specified output directory.
EOF
    exit 1
fi

FILENAME=$1
OUTPUTDIR=$2
OUTPUTPREFIX=$3

if [ ! "$FILENAME" ]; then
    echo "$PROGNAME: An input filename must be specified." 1>&2
    exit 1
fi

if [ ! "$OUTPUTDIR" ]; then
    echo "$PROGNAME: An output directory must be specified." 1>&2
    exit 1
fi

if [ ! "$OUTPUTPREFIX" ]; then
    echo "$PROGNAME: An output prefix for the archives must be specified." 1>&2
    exit 1
fi

WORKDIR="$OUTPUTDIR/$OUTPUTPREFIX"
ARCHIVEBASE="${OUTPUTPREFIX}_`date +%m%d%Y`"
INTERVAL=20000

if [ ! -e "$WORKDIR" ]; then
    mkdir "$WORKDIR"
else
    echo "$PROGNAME: Removing spurious working directory contents: $WORKDIR" 1>&2
    rm -r "$WORKDIR/"*
fi

# Trap any unforeseen exits, removing the working directory.

trap 'rmdir "$WORKDIR" ; exit 1' INT TERM EXIT

# Identify pieces of the input file each having INTERVAL lines.
# Present the start line and INTERVAL to a pipeline that slices the file into
# the pieces, then processing each piece in a separate working directory in
# order to create an archive file for that piece.

  seq 1 $INTERVAL `wc -l "$FILENAME" | cut -f 1 -d ' '` \
| "$SCRIPTS/irparallel" "echo {} $INTERVAL | \"$SCRIPTS/irslice\" \"$FILENAME\" --lines - | \"$TOOLS/irdata_archive_irefscape_bundle.sh\" \"$WORKDIR/{}\" \"$OUTPUTDIR/${ARCHIVEBASE}_{}.irfj\""

trap - INT TERM EXIT

# Finally, remove the working directory.

rmdir "$WORKDIR"
