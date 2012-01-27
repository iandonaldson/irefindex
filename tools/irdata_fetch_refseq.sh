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

QUERYFILE="$FILENAME.query"
RESULTFILE="$FILENAME.result"

# Execute a query to get feature table output for proteins.

echo -n "tool=$EUTILS_TOOL&email=$EUTILS_EMAIL&db=protein&rettype=gp&retmode=text&id=" > "$QUERYFILE"

# Convert the list of identifiers into form-encoded parameters.

python -c 'import sys; sys.stdout.write(sys.stdin.read().replace("\n", ",").rstrip(","))' < "$FILENAME" >> "$QUERYFILE"

wget -O "$RESULTFILE" "$EFETCH_URL" --post-file="$QUERYFILE"

# Parse the feature table output, producing files similar to those normally
# available for RefSeq.

"$TOOLS/irdata_parse_refseq.py" "$DATADIR" "$RESULTFILE"

# Concatenate the output data.

cat "$DATADIR"/*_proteins > "$DATADIR/refseq_proteins.txt"
cat "$DATADIR"/*_identifiers > "$DATADIR/refseq_identifiers.txt"
cat "$DATADIR"/*_nucleotides > "$DATADIR/refseq_nucleotides.txt"

# Process the sequence data.

"$TOOLS/irdata_process_signatures.sh" "$DATADIR"
exit $?