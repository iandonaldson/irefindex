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

Process the UniProt files (typically in UniProt text format and FASTA format),
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

for FILENAME in $FILENAMES; do
    BASENAME=`basename "$FILENAME"`
    FILETYPE=${BASENAME#*.}

    # Parse the FASTA files.

    if [[ "$FILETYPE" = 'fasta' || "$FILETYPE" = 'fasta.gz' ]]; then
        if ! "$TOOLS/irdata_parse_fasta.py" "$DATADIR" 'sp,acc,id' 'id,acc,date,taxid' "$FILENAME" ; then
            echo "$PROGNAME: FASTA parsing of $FILENAME failed." 1>&2
            exit 1
        fi

    # Parse the data files.

    elif [[ "$FILETYPE" = 'dat' || "$FILETYPE" = 'dat.gz' ]]; then
        if ! "$TOOLS/irdata_parse_uniprot.py" "$DATADIR" "$FILENAME" ; then
            echo "$PROGNAME: UniProt text parsing of $FILENAME failed." 1>&2
            exit 1
        fi
    else
        echo "$PROGNAME: Data file $FILENAME is not supported." 1>&2
    fi
done

"$TOOLS/irdata_process_signatures.sh" "$DATADIR"
exit $?
