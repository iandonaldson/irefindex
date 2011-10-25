#!/bin/sh

if [ -e "irdata-config" ]; then
    . "$PWD/irdata-config"
elif [ -e "scripts/irdata-config" ]; then
    . 'scripts/irdata-config'
else
    . 'irdata-config'
fi

OUTFILE='table.txt'

if [ "$1" = '--help' ]; then
    cat 1>&2 <<EOF
Usage: $PROGNAME <output data directory> <filename>

Process the MMDB table file, producing data suitable for iRefIndex in a file
called $OUTFILE in the output data directory.
EOF
    exit 1
fi

DATADIR=$1
FILENAME=$2

if [ ! "$DATADIR" ] || [ ! "$FILENAME" ]; then
    echo "$PROGNAME: A data directory and an input filename or - must be specified." 1>&2
    exit 1
fi

# Remove comment lines, convert the field delimiters, extract the PDB accession,
# chain, gi and taxid.

  grep -v -e '^#' "$FILENAME" \
| sed 's/^ *//' \
| sed $'s/ \{2,\}/\t/'g \
| cut -f 2,3,4,5 \
> "$DATADIR/$OUTFILE"
