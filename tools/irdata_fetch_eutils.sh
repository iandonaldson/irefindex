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

Using a list of identifiers provided via standard input, make a request to the
Entrez utilities service, writing the response to standard output.
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

# Convert the list of identifiers into form-encoded parameters.

   tr '\n' ',' \
|  sed -e 's/,$//' \
>> "$QUERYFILE"

# Wait before wget because the retrieval operation will only get one resource.

echo "$PROGNAME: Waiting for $WGET_WAIT..." 1>&2
sleep "$WGET_WAIT"

if ! wget -O - "$EFETCH_URL" --post-file="$QUERYFILE" ; then
    echo "$PROGNAME: Could not download the missing sequence records from RefSeq." 1>&2
    exit 1
fi
