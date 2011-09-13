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
Usage: $PROGNAME <output data directory>

Process sequence data files, creating new files with the sequences replaced by
signatures/digests of the sequence data.
EOF
    exit 1
fi

DATADIR=$1

for FILENAME in "$DATADIR/"*_proteins.txt ; do
    if ! "$TOOLS/irdata_process_signatures.py" "$FILENAME" "$FILENAME.seq" ; then
        echo "$PROGNAME: Sequence digest processing of $FILENAME failed." 1>&2
        exit 1
    fi
done
