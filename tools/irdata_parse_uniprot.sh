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

        # Unpack any gzip archives since the slicing of these files is not
        # efficient if done repeatedly.

        if [ "$FILETYPE" = 'dat.gz' ]; then
            echo "$PROGNAME: Unpacking $FILENAME..." 1>&2
            "$SCRIPTS/irunpack-archive" --include-gzip-files "$FILENAME"
            FILENAME=${FILENAME%.gz}
        fi

        # Remove the extension from the filename.

        BASENAME=`basename "$FILENAME"`
        LEAFNAME=${BASENAME%.dat}

        # Split the data file into pieces by first finding the offsets in the
        # filename.

          "$TOOLS/irdata_split.py" -1 "$UNIPROT_SPLIT_INTERVAL" "$FILENAME" '//' \
        | "$SCRIPTS/irparallel" "echo {} | \"$SCRIPTS/irslice\" \"$FILENAME\" - | \"$TOOLS/irdata_parse_uniprot.py\" \"$DATADIR\" - \"${LEAFNAME}_%s-{}.txt\""

        # Merge the pieces.

        for TYPE in "accessions" "gene_names" "identifiers" "proteins" ; do
            if cat "$DATADIR/${LEAFNAME}_${TYPE}-"*".txt" > "$DATADIR/${LEAFNAME}_${TYPE}.txt" ; then
                for PIECE in "$DATADIR/${LEAFNAME}_${TYPE}-"*".txt" ; do
                    rm "$PIECE"
                done
            fi
        done

    else
        echo "$PROGNAME: Data file $FILENAME is not supported." 1>&2
    fi
done

"$TOOLS/irdata_process_signatures.sh" "$DATADIR" --append-length
exit $?
