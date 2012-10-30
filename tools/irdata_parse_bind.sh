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
Usage: $PROGNAME <output data directory> <filename>...

Process the BIND files, producing data suitable for iRefIndex in the output data
directory.
EOF
    exit 1
fi

DATADIR=$1
shift 1

FILENAMES=$*

if [ ! "$DATADIR" ] || [ ! "$FILENAMES" ]; then
    echo "$PROGNAME: A data directory and an input filename must be specified." 1>&2
    exit 1
fi

for FILENAME in $FILENAMES; do
    BASENAME=`basename "$FILENAME"`
    FILETYPE=${BASENAME#*.}

    # Quote the filename so that we can use it in a sed expression.

    SED_FILENAME=$( echo "$FILENAME" | sed 's/\//\\\//g' )

    if [ "$FILETYPE" = 'ints.txt' ]; then

        # First interactor (add filename and position 0).

          cut -f 1,2,3,4,5,6,7 "$FILENAME" \
        | uniq \
        | sed -e "s/^/$SED_FILENAME\t0\t/" \
        > "$DATADIR/interactors.txt"

        # Second interactor (add filename and position 1).

          cut -f 1,2,8,9,10,11,12 "$FILENAME" \
        | uniq \
        | sed -e "s/^/$SED_FILENAME\t1\t/" \
        >> "$DATADIR/interactors.txt"

    elif [ "$FILETYPE" = 'refs.txt' ]; then

        # Pad the file in order to add missing methods.

          "$TOOLS/irdata_text_pad.py" -n 4 -p \\N "$FILENAME" \
        > "$DATADIR/references.txt"

    elif [ "$FILETYPE" = 'complex2refs.txt' ]; then

        cp "$FILENAME" "$DATADIR/complex_references.txt"

    elif [ "$FILETYPE" = 'complex2subunits.txt' ]; then

        # Add the line number as the interactor identifier.
        # Then transpose each line to make a collection of lines with a
        # different alias on each one.

          sed -n -e 'p;=' "$FILENAME" \
        | sed -e 'N;s/\n/\t/' \
        | "$TOOLS/irdata_text_transpose.py" -f 8 -t 8 -w '|' -s 0 - \
        | sed -e "s/^/$SED_FILENAME\t/" \
        > "$DATADIR/complexes.txt"

    elif [ "$FILETYPE" = 'labels.txt' ]; then

        # First interactor (add position 0).

          cut -f 1,2,4 "$FILENAME" \
        | "$TOOLS/irdata_text_transpose.py" -f 3 -w '|' -s 0 - \
        | sed -e "s/^/0\t/" \
        > "$DATADIR/labels.txt"

        # Second interactor (add position 1).

          cut -f 1,3,5 "$FILENAME" \
        | "$TOOLS/irdata_text_transpose.py" -f 3 -w '|' -s 0 - \
        | sed -e "s/^/1\t/" \
        >> "$DATADIR/labels.txt"

    fi

done
