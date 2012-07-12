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

Process the GenPept files (typically in FASTA format), producing data suitable
for iRefIndex in the output data directory.
EOF
    exit 1
fi

DATADIR=$1
shift 1

FILENAMES=$*

if [ ! "$DATADIR" ] || [ ! "$FILENAMES" ]; then
    echo "$PROGNAME: A data directory and input filenames must be specified." 1>&2
    exit 1
fi

  "$SCRIPTS/argument-per-line" $FILENAMES \
| "$SCRIPTS/irparallel" "\"$TOOLS/irdata_parse_fasta.py\" \"$DATADIR\" 'gi,ginr,db,acc,organism' 'acc,db,ginr,organism' {}"

# Concatenate the output data, isolating the organism name from the organism
# column.
# NOTE: Tab character used in the final command.

  cat "$DATADIR"/*_proteins.txt \
| sed -e 's/\(.*\)	\(.*\)	\(.*\)	.*\[\(.*\)\]	\(.*\)/\\1	\\2	\\3	\\4	\\5/' \
> "$DATADIR/genpept_proteins.txt"

"$TOOLS/irdata_process_signatures.sh" "$DATADIR"
exit $?
