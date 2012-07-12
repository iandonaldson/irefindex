#!/bin/sh

# Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

Parse the release file from FlyBase and emit manifest information.
EOF
    exit 1
fi

FILENAME=$1

if [ ! "$FILENAME" ]; then
    echo "$PROGNAME: An input filename must be specified." 1>&2
    exit 1
fi

# Tab character used in the sed commands.
TAB=`printf '\t'`

# Look for "Release: 9999_99 of 99-ZZZ-9999" and emit that as the version and date.

PATTERN='[[:digit:]]\{4\}_[[:digit:]]\{2\}'

  grep -e '^Release:' "$FILENAME" \
| head -n 1 \
| sed -e "s/.*\($PATTERN\).*/\\1/" \
| sed -e "s/\(.*\)/VERSION${TAB}\\1/"

# Look for "99-ZZZ-9999" and emit that as the date.

PATTERN='[[:digit:]]\{2\}-[[:alpha:]]\{3\}-[[:digit:]]\{4\}'

  grep -e '^Release:' "$FILENAME" \
| head -n 1 \
| sed -e "s/.*\($PATTERN\).*/\\1/" \
| sed -e "s/\(.*\)/DATE${TAB}\\1/"
