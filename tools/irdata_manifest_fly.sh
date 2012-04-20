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
Usage: $PROGNAME <filename>

Parse the release file from FlyBase and emit manifest information.
EOF
    exit 1
fi

FILENAME=$1

if [ ! "$FILENAME" ]; then
    echo "$PROGNAME: An input filename must be specified." 1>&2
    exit 1
fi

# Look for "Release: 9999_99 of 99-ZZZ-9999" and emit that as the version and date.

PATTERN=$'[[:digit:]]\{4\}_[[:digit:]]\{2\}'

  grep -e '^Release:' "$FILENAME" \
| head -n 1 \
| sed -e $"s/.*\($PATTERN\).*/\\1/" \
| sed -e $'s/\(.*\)/VERSION\t\\1/'

# Look for "99-ZZZ-9999" and emit that as the date.

PATTERN=$'[[:digit:]]\{2\}-[[:alpha:]]\{3\}-[[:digit:]]\{4\}'

  grep -e '^Release:' "$FILENAME" \
| head -n 1 \
| sed -e $"s/.*\($PATTERN\).*/\\1/" \
| sed -e $'s/\(.*\)/DATE\t\\1/'
