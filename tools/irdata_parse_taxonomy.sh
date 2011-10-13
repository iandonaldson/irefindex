#!/bin/sh

if [ -e "irdata-config" ]; then
    . "$PWD/irdata-config"
elif [ -e "scripts/irdata-config" ]; then
    . 'scripts/irdata-config'
else
    . 'irdata-config'
fi

OUTFILE='names.txt'

if [ "$1" = '--help' ]; then
    cat 1>&2 <<EOF
Usage: $PROGNAME <output data directory> <filename>

Process the Taxonomy names file (typically names.dmp), producing data suitable
for iRefIndex in a file called $OUTFILE in the output data directory.
EOF
    exit 1
fi

DATADIR=$1
FILENAME=$2

if [ ! "$DATADIR" ] || [ ! $FILENAME ]; then
    echo "$PROGNAME: A data directory and an input filename must be specified." 1>&2
    exit 1
fi

# Convert the bizarre format to a plain tab-separated format.

  sed $'s/\t|\t/\t/g;s/\t|$//;' "$FILENAME" \
> "$DATADIR/$OUTFILE"

exit $?
