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
Usage: $PROGNAME <filename>...

Fix the XML encoding declaration in the given files.
EOF
    exit 1
fi

FILENAMES=$*

for FILENAME in $FILENAMES; do
    XMLENC=`grep '^<?xml ' "$FILENAME" | head -n 1`
    if [ "$XMLENC" ]; then
        echo "$PROGNAME: An existing declaration is provided and will not be changed: $FILENAME" 1>&2
        echo "$PROGNAME: $XMLENC" 1>&2
    else
        echo "$PROGNAME: Inserting a declaration: $FILENAME" 1>&2
        mv "$FILENAME" "$FILENAME.orig"
        cat "$RESOURCES/xml_encoding.txt" "$FILENAME.orig" > "$FILENAME"
    fi
done
