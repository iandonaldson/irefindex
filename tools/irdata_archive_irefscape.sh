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
Usage: $PROGNAME <directory> <archive directory>

Make an archive of iRefScape data using the files in the given directory
(typically a directory called iRefScape inside the main data output directory),
writing the archive (with a date-specific filename) to the specified location.
EOF
    exit 1
fi

DATADIR=$1
ARCHIVEDIR=$2

if [ ! "$DATADIR" ]; then
    echo "$PROGNAME: A directory must be specified." 1>&2
    exit 1
fi

if [ ! "$ARCHIVEDIR" ]; then
    echo "$PROGNAME: An output directory must be specified." 1>&2
    exit 1
fi

# Make the separate RIG and ROG indexes.

"$TOOLS/irdata_index_irefscape_data.sh" "$DATADIR/rigAttributes.irfi" "$DATADIR/rigAttributes.irfx"
"$TOOLS/irdata_index_irefscape_data.sh" "$DATADIR/rogAttributes.irfi" "$DATADIR/rogAttributes.irfx"



# Convert the graph to the Java serialisation format.

"$TOOLS/irdata_convert_graph.py" "$DATADIR/graph.txt" "$DATADIR/graph"



# Write a release description.
# NOTE: Using legacy date format.

DATESTAMP=`date +%m%d%Y`
echo $DATESTAMP > "$DATADIR/irefscape_date.txt"

cat > "$DATADIR/RELEASE" <<EOF
#irefindex.uio.no
#`date +%Y-%m-%d`
# Format: <human-readable version>%<machine-readable version>
CURRENT_DATA_VERSION=${RELEASE}%${RELEASE}
CURRENT_DATA_LOCATION_FTP=$IREFINDEX_RELEASE_SITE
CURRENT_DATA_LOCATION_DIRECTORY=$IREFINDEX_RELEASE_PATH
CURRENT_DATA_LOCATION_USER=$IREFINDEX_RELEASE_USER
CURRENT_DATA_LOCATION_PASS=$IREFINDEX_RELEASE_PASSWORD
CURRENT_DATA_PROPRIETARY=$IREFINDEX_PROPRIETARY_DATA
EOF



# Remove any existing archive.

ARCHIVE="$ARCHIVEDIR/iRefDATA_$DATESTAMP.irfz"

if [ -e "$ARCHIVE" ]; then
    rm "$ARCHIVE"
fi

# Package the different files.

cd "$RESOURCES" && jar cf "$ARCHIVE" *.irct
cd "$DATADIR" && jar uf "$ARCHIVE" *.irf[imtx] graph RELEASE

# Write the archive location to standard output.

echo "$ARCHIVE"
