#!/bin/sh

# Copyright (C) 2011, 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
# Original author: Paul Boddie <paul.boddie@biotek.uio.no>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.

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

    if [ "$FILETYPE" = 'fasta' ] || [ "$FILETYPE" = 'fasta.gz' ]; then
        if ! "$TOOLS/irdata_parse_fasta.py" "$DATADIR" 'sp,acc,id' 'id,acc,date,taxid,mw' "$FILENAME" ; then
            echo "$PROGNAME: FASTA parsing of $FILENAME failed." 1>&2
            exit 1
        fi

    # Parse the data files.

    elif [ "$FILETYPE" = 'dat' ] || [ "$FILETYPE" = 'dat.gz' ]; then

        # Unpack any gzip archives since the slicing of these files is not
        # efficient if done repeatedly.

        if [ "$FILETYPE" = 'dat.gz' ]; then
            UNPACKED_FILENAME=${FILENAME%.gz}

            # Unpack the archive again even if an uncompressed file is present.

            if [ -e "$UNPACKED_FILENAME" ] && [ -e "$FILENAME" ]; then
                echo "$PROGNAME: Removing existing $UNPACKED_FILENAME..." 1>&2
                rm "$UNPACKED_FILENAME"
            fi

            echo "$PROGNAME: Unpacking $FILENAME..." 1>&2
            "$SCRIPTS/irunpack-archive" --include-gzip-files "$FILENAME"
            FILENAME=$UNPACKED_FILENAME
        fi

        # Remove the extension from the filename.

        BASENAME=`basename "$FILENAME"`
        LEAFNAME=${BASENAME%.dat}

        # Split the data file into pieces by first finding the offsets in the
        # filename.

          "$TOOLS/irdata_split.py" -1 "$UNIPROT_SPLIT_INTERVAL" "$FILENAME" '//' \
        | "$SCRIPTS/irparallel" "echo {} | \"$SCRIPTS/irslice\" \"$FILENAME\" - | \"$TOOLS/irdata_parse_uniprot.py\" \"$DATADIR\" - \"${LEAFNAME}_%s-{}.txt\""

        # Merge the pieces.

        echo "$PROGNAME: Merging data files for $LEAFNAME..." 1>&2

        for TYPE in "accessions" "gene_names" "identifiers" "proteins" ; do
            if cat "$DATADIR/${LEAFNAME}_${TYPE}-"*".txt" > "$DATADIR/${LEAFNAME}_${TYPE}.txt" ; then
                for PIECE in "$DATADIR/${LEAFNAME}_${TYPE}-"*".txt" ; do
                    rm "$PIECE"
                done
            else
                echo "$PROGNAME: Failed to concatenate data files for ${LEAFNAME}_${TYPE}." 1>&2
                exit 1
            fi
        done

        # Filter the identifiers in order to avoid huge files containing
        # superfluous identifier details.

        UNFILTERED="$DATADIR/${LEAFNAME}_identifiers.txt"
        FILTERED="$DATADIR/${LEAFNAME}_identifiers.txt.filtered"

        if [ -e "$UNFILTERED" ] && grep 'GeneID' "$UNFILTERED" > "$FILTERED" ; then
            mv "$FILTERED" "$UNFILTERED"
        fi

    else
        echo "$PROGNAME: Data file $FILENAME is not supported." 1>&2
    fi
done

"$TOOLS/irdata_process_signatures.sh" "$DATADIR" --append-length
exit $?
