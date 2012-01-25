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
| "$SCRIPTS/irparallel" "\"$TOOLS/irdata_parse_fasta.py\" \"$DATADIR\" 'gi,ginr,db,acc' 'acc,db,ginr' {}"

# Concatenate the output data.

cat "$DATADIR"/*_proteins.txt > "$DATADIR/genpept_proteins.txt"

"$TOOLS/irdata_process_signatures.sh" "$DATADIR"
exit $?
