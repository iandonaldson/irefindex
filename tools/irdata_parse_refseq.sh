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
Usage: $PROGNAME <output data directory> <filename>...

Process the RefSeq files (typically in the "feature table" text format),
producing data suitable for iRefIndex in the output data directory.
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

# Parse the data files.

  "$SCRIPTS/argument-per-line" $FILENAMES \
| "$SCRIPTS/irparallel" "\"$TOOLS/irdata_parse_refseq.py\" \"$DATADIR\" {}"

# Concatenate the output data.

cat "$DATADIR"/* > "$DATADIR/refseq_proteins.txt"

# Process the sequence data.

"$TOOLS/irdata_process_signatures.sh" "$DATADIR"
exit $?
