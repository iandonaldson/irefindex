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

Process the given files, writing to the output data directory.
EOF
    exit 1
fi

DATADIR=$1
shift 1

FILENAMES=$*

if [ ! "$DATADIR" ] || [ ! "$FILENAMES" ]; then
    echo "$PROGNAME: A data directory and an input filename must be specified." 1>&2
    exit 1
fi

for FILENAME in $FILENAMES; do
    BASENAME=`basename "$FILENAME"`
    LEAFNAME=${BASENAME%.*}

    if [ "$LEAFNAME" = 'gene2refseq' ]; then
        "$TOOLS/irdata_parse_gene2refseq.sh" "$DATADIR" "$FILENAME"
    elif [ "$LEAFNAME" = 'gene_info' ]; then
        "$TOOLS/irdata_parse_gene_info.sh" "$DATADIR" "$FILENAME"
    fi
done

# NOTE: Need parsers for gene_info, gene2go.
