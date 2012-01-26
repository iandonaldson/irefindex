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
ACCESSIONSFILE="$FILENAME.accessions"
SEQUENCESFILE="$FILENAME.sequences"

# Convert the list of identifiers into form-encoded parameters.

echo -n 'db=protein&id=' > "$QUERYFILE"
python -c 'import sys; sys.stdout.write(sys.stdin.read().replace("\n", ",").rstrip(","))' < "$FILENAME" >> "$QUERYFILE"

# Perform the identifier upload.

wget --post-file="$QUERYFILE" -O "$RESULTFILE" "$EPOST_URL"

# Process the upload results and extract the WebEnv identifier, building the
# form-encoded parameters.

cat "$RESULTFILE"
WEBENV=`xsltproc "$TOOLS/irdata_epost2text.xsl" "$RESULTFILE"`

# Execute a query to get accessions, one per line.

wget -O "$ACCESSIONSFILE" "$EFETCH_URL?db=protein&rettype=acc&retmode=text&query_key=1&WebEnv=$WEBENV"

# Execute a query to get sequences.

wget -O "$SEQUENCESFILE" "$EFETCH_URL?db=protein&rettype=fasta&retmode=xml&query_key=1&WebEnv=$WEBENV"

# Combine the accessions.

paste "$FILENAME" "$ACCESSIONSFILE" > "$DATADIR/unknown_refseq_accessions.txt"

# Process the results.

xsltproc "$TOOLS/irdata_tseq2tab.xsl" "$RESULTFILE" > "$DATADIR/unknown_refseq_proteins.txt"
