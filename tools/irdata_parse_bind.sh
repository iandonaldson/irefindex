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

Process the BIND files, producing data suitable for iRefIndex in the output data
directory.
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
    FILETYPE=${BASENAME#*.}
    SED_FILENAME=$( echo "$FILENAME" | sed 's/\//\\\//g' )

    if [ "$FILETYPE" = 'ints.txt' ]; then

        # First interactor (add position 0).

          cut -f 1,2,3,4,5,6,7 "$FILENAME" \
        | sed -e "s/^/$SED_FILENAME\t0\t/" \
        > "$DATADIR/interactors.txt"

        # Second interactor (add position 1).

          cut -f 1,2,8,9,10,11,12 "$FILENAME" \
        | sed -e "s/^/$SED_FILENAME\t1\t/" \
        >> "$DATADIR/interactors.txt"

    elif [ "$FILETYPE" = 'refs.txt' ]; then

        # Pad the file in order to add missing methods.

          "$TOOLS/irdata_text_pad.py" -n 4 -p \\N "$FILENAME" \
        > "$DATADIR/references.txt"

    elif [ "$FILETYPE" = 'complex2refs.txt' ]; then

        cp "$FILENAME" "$DATADIR/complex_references.txt"

    elif [ "$FILETYPE" = 'complex2subunits.txt' ]; then

          "$TOOLS/irdata_text_transpose.py" -f 8 -w '|' -s 0 "$FILENAME" \
        | sed -e "s/^/$SED_FILENAME\t/" \
        > "$DATADIR/complexes.txt"

    elif [ "$FILETYPE" = 'labels.txt' ]; then

        # First interactor (add position 0).

          cut -f 1,2,4 "$FILENAME" \
        | "$TOOLS/irdata_text_transpose.py" -f 3 -w '|' -s 0 - \
        | sed -e "s/^/0\t/" \
        > "$DATADIR/labels.txt"

        # Second interactor (add position 1).

          cut -f 1,3,5 "$FILENAME" \
        | "$TOOLS/irdata_text_transpose.py" -f 3 -w '|' -s 0 - \
        | sed -e "s/^/1\t/" \
        >> "$DATADIR/labels.txt"

    fi

done
