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

Process the given files, writing to the output data directory.
EOF
    exit 1
fi

DATADIR=$1
FILENAME=$2

if [ ! "$DATADIR" ] || [ ! "$FILENAME" ]; then
    echo "$PROGNAME: A data directory and an input filename must be specified." 1>&2
    exit 1
fi

RESULTFILE="$FILENAME.result"

# Split the filename into manageable pieces and process each one in turn.
# Note that this is done serially due to Entrez usage restrictions.

  "$TOOLS/irdata_split.py" -1 10000 "$FILENAME" \
| xargs $XARGS_I'{}' sh -c "echo {} | \"$SCRIPTS/irslice\" \"$FILENAME\" - | \"$TOOLS/irdata_fetch_eutils.sh\" \"$FILENAME\"" \
> "$RESULTFILE"

# Parse the feature table output, producing files similar to those normally
# available for RefSeq.

if ! "$TOOLS/irdata_parse_refseq.py" "$DATADIR" "$RESULTFILE" ; then
    echo "$PROGNAME: Could not parse the retrieved data." 1>&2
    exit 1
fi

# Concatenate the output data.

cat "$DATADIR"/*_proteins > "$DATADIR/refseq_proteins.txt"
cat "$DATADIR"/*_identifiers > "$DATADIR/refseq_identifiers.txt"
cat "$DATADIR"/*_nucleotides > "$DATADIR/refseq_nucleotides.txt"

# Process the sequence data.

"$TOOLS/irdata_process_signatures.sh" "$DATADIR" --append --append-length
exit $?
