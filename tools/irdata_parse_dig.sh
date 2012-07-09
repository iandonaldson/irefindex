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
Usage: $PROGNAME <output data directory> <filename>

Process the disease groups file, producing data suitable for iRefIndex in a file
of the same name in the output data directory.
EOF
    exit 1
fi

DATADIR=$1
FILENAME=$2

if [ ! "$DATADIR" ] || [ ! "$FILENAME" ]; then
    echo "$PROGNAME: A data directory and an input filename must be specified." 1>&2
    exit 1
fi

TMPFILE="$DATADIR/_dig.txt"

# Parse the file using the Python-based parser.

  "$TOOLS/irdata_parse_dig.py" "$FILENAME" \
> "$TMPFILE"

# Then create different files for the parsed information.

# The main file excludes the genes.

  cut -f 1,2,3,4,6,7 "$TMPFILE" \
> "$DATADIR/dig.txt"

# The genes file maps DIG identifiers to genes.

  cut -f 1,5 "$TMPFILE" \
| "$TOOLS/irdata_text_transpose.py" -f 2 -w '|' - \
| sort -u \
> "$DATADIR/dig_genes.txt"

rm "$TMPFILE"
