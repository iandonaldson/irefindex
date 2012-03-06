#!/bin/sh

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

Process the UniProt FlyBase or Yeast file (typically fly.txt or yeast.txt),
producing data suitable for iRefIndex in a file with the same name in the output
data directory.
EOF
    exit 1
fi

DATADIR=$1
FILENAME=$2

if [ ! "$DATADIR" ] || [ ! "$FILENAME" ]; then
    echo "$PROGNAME: A data directory and an input filename or - must be specified." 1>&2
    exit 1
fi

OUTFILE=`basename "$FILENAME"`
FILETYPE=${OUTFILE%%.*}

# Find the last table header marker.

START=`grep -ne '^__' "$FILENAME" | tail -n 1 | cut -d ':' -f 1`

# Find the footer.

END=`grep -ne '^----' "$FILENAME" | tail -n 2 | head -n 1 | cut -d ':' -f 1`

# Slice the file and present it to the parser.

  head -n $((END - 1)) "$FILENAME" \
| tail -n "+$START" \
| "$TOOLS/irdata_parse_fly.py" "$FILETYPE" --discard-ill-formed \
> "$DATADIR/$OUTFILE"
