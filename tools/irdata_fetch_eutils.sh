#!/bin/sh

# Copyright (C) 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
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
Usage: $PROGNAME <filename>

Using a list of identifiers provided via standard input, make a request to the
Entrez utilities service, writing the response to standard output. The given
filename is used to name the temporary query file used by wget to make the
request, along with a temporary file containing the input.
EOF
    exit 1
fi

FILENAME=$1

if [ ! "$FILENAME" ]; then
    echo "$PROGNAME: An input filename must be specified." 1>&2
    exit 1
fi

QUERYFILE="$FILENAME.query"

# Execute a query to get feature table output for proteins.

  echo -n "tool=$EUTILS_TOOL&email=$EUTILS_EMAIL&db=protein&rettype=gp&retmode=text&id=" \
> "$QUERYFILE"

# Hold the input in a temporary file in case of failure.
# Convert the list of identifiers into form-encoded parameters.

   tee "$FILENAME.input" \
|  tr '\n' ',' \
|  sed -e 's/,$//' \
>> "$QUERYFILE"

# Wait before wget because the retrieval operation will only get one resource.

echo "$PROGNAME: Waiting for $WGET_WAIT..." 1>&2
sleep "$WGET_WAIT"

# Perform the download, adding the input to the failed input file upon any
# failure. Capture results in case the operation fails.

if ! wget -O "$FILENAME.output" "$EFETCH_URL" --post-file="$QUERYFILE" ; then
    echo "$PROGNAME: Could not download the missing sequence records from RefSeq." 1>&2
    cat "$FILENAME.input" >> "$FILENAME.failed"
    exit 1

# Even though wget may be convinced of success, E-utils may have failed and
# appended nonsense to the file, so this must be tested.

else
    ENDING=`tail -n 2 "$FILENAME.output"`

    if [ "$ENDING" != '//' ]; then
        echo "$PROGNAME: Output appeared to be ill-formed, perhaps due to a service error." 1>&2
        cat "$FILENAME.input" >> "$FILENAME.failed"
        mv "$FILENAME.output" "$FILENAME.output.`date +%Y%m%dT%H%M%S`"
        exit 1

    # On success, emit the results.

    else
        cat "$FILENAME.output"
    fi
fi
