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

Process the IPI files (typically in FASTA format), producing data suitable for
iRefIndex in the output data directory.
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
    FILETYPE=${BASENAME##*.}
    if [[ "$FILETYPE" = 'fasta' || "$FILETYPE" = 'gz' ]]; then
        if ! "$TOOLS/irdata_parse_fasta.py" "$DATADIR" 'acc' 'acc' "$FILENAME" ; then
            echo "$PROGNAME: FASTA parsing of $FILENAME failed." 1>&2
            exit 1
        fi

        # Get the accession mapping by extracting header lines and splitting the entries.
        # Remove the ">" marker.
        # Split using " " and extract the identifiers and taxid.
        # Convert the " " delimiter to make the taxid like the other identifiers.
        # Transpose the contents of the identifiers, grouping by the first "IPI:..." field.
        # Split using ":" and "=" to separate database labels and identifiers.
        # Remove the redundant "IPI" label.
        # Transpose the identifiers where provided in a list.

          grep -e '^>' "$FILENAME" \
        | cut -d '>' -f 2- \
        | cut -d ' ' -f 1,2 \
        | sed -e 's/ /|/g' \
        | "$TOOLS/irdata_text_transpose.py" -f 2 -d '|' - \
        | sed -e 's/[:=]/\t/g' \
        | cut -f 2- \
        | "$TOOLS/irdata_text_transpose.py" -f 3 -w ';' - \
        > "$DATADIR/${BASENAME}_identifiers.txt"

    else
        echo "$PROGNAME: Data file $FILENAME is not supported." 1>&2
    fi
done

if "$TOOLS/irdata_process_signatures.sh" "$DATADIR" ; then

    if [ -e "$DATADIR/ipi_proteins.txt.seq" ]; then
        rm "$DATADIR/ipi_proteins.txt.seq"
    fi

    if [ -e "$DATADIR/ipi_identifiers.txt" ]; then
        rm "$DATADIR/ipi_identifiers.txt"
    fi

    # Concatenate and tidy up the protein files.

      cat "$DATADIR/"*"_proteins.txt.seq" \
    | cut -d ':' -f 2- \
    > "$DATADIR/ipi_proteins.txt.seq"

    # Concatenate the identifier files.

      cat "$DATADIR/"*"_identifiers.txt" \
    > "$DATADIR/ipi_identifiers.txt"

fi

exit $?
