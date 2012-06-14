#!/bin/sh

# Copyright (C) 2011, 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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
Usage: $PROGNAME <output data directory> [ <option>... ]

Process sequence data files, creating new files with the sequences replaced by
signatures/digests of the sequence data. Any options are passed to the
underlying digest processing program.
EOF
    exit 1
fi

DATADIR=$1
shift 1

if [ ! "$DATADIR" ]; then
    echo "$PROGNAME: A data directory must be specified." 1>&2
    exit 1
fi

for FILENAME in "$DATADIR/"*_proteins.txt ; do
    if [ "$FILENAME" = "$DATADIR/*_proteins.txt" ]; then
        echo "$PROGNAME: No processable files were found." 1>&2
        exit 1
    fi

    if ! "$TOOLS/irdata_process_signatures.py" "$FILENAME" "$FILENAME.seq" $* ; then
        echo "$PROGNAME: Sequence digest processing of $FILENAME failed." 1>&2
        exit 1
    fi
done
