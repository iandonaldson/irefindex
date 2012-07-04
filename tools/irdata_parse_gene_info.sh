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

OUTFILE_INFO='gene_info.txt'
OUTFILE_SYNONYMS='gene_synonyms.txt'
OUTFILE_MAPLOCATIONS='gene_maplocations.txt'

if [ "$1" = '--help' ]; then
    cat 1>&2 <<EOF
Usage: $PROGNAME <output data directory> <filename>

Process the gene_info file (typically gene_info.gz), producing data suitable
for iRefIndex in the following files in the output data directory:

$OUTFILE_INFO
$OUTFILE_SYNONYMS
$OUTFILE_MAPLOCATIONS
EOF
    exit 1
fi

DATADIR=$1
FILENAME=$2

if [ ! "$DATADIR" ] || [ ! "$FILENAME" ]; then
    echo "$PROGNAME: A data directory and an input filename or - must be specified." 1>&2
    exit 1
fi

FILETYPE=${FILENAME##*.}

if [ "$FILETYPE" = "gz" ]; then
    READER='gunzip -c "$FILENAME"'
else
    READER='cat "$FILENAME"'
fi

# Uncompress, remove the header, extract the taxid, geneid, symbol, locustag and
# chromosome.
# Then filter out records where information is missing.

  eval "$READER" \
| tail -n +2 \
| cut -f 1,2,3,4,7 \
| grep -v -e 'NEWENTRY' \
> "$DATADIR/$OUTFILE_INFO"

# For maplocations, remove the header, extract the geneid and synonyms.
# Then filter out records where information is missing.
# Transpose the data by splitting the third column on "|" and numbering the
# entries from zero.

  eval "$READER" \
| tail -n +2 \
| cut -f 2,8 \
| grep -v -e 'NEWENTRY' \
| "$TOOLS/irdata_text_transpose.py" -f 2 -w '|' -s 0 - \
> "$DATADIR/$OUTFILE_MAPLOCATIONS"

# For synonyms, remove the header, extract the geneid and synonyms.
# Transpose the data by splitting the third column on "|" and numbering the
# entries from zero.

  eval "$READER" \
| tail -n +2 \
| cut -f 2,5 \
| grep -v -e 'NEWENTRY' \
| "$TOOLS/irdata_text_transpose.py" -f 2 -w '|' -s 0 - \
> "$DATADIR/$OUTFILE_SYNONYMS"
