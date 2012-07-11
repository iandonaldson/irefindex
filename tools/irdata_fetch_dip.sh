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
Usage: $PROGNAME [ --check ] [ -v | --verbose ] <output data directory>

Fetch the download for DIP, writing to the output data directory.
EOF
    exit 1
fi

if [ "$1" = '--check' ]; then
    CHECK_ONLY=$1
    shift 1
fi

if [ "$1" = '-v' ] || [ "$1" = '--verbose' ]; then
    VERBOSE=$1
    shift 1
fi

DATADIR=$1

if [ ! "$DATADIR" ]; then
    echo "$PROGNAME: A data directory must be specified." 1>&2
    exit 1
fi

if [ ! -e "$DATADIR" ]; then
    mkdir "$DATADIR"
fi

# Log into the DIP site.

FORMDATA="lgn=1&login=$DIP_USERNAME&pass=$DIP_PASSWORD&Login=Login"
DIP_COOKIES="$DATADIR/dip_cookies.txt"

  wget -O - --save-cookies "$DIP_COOKIES" --post-data "$FORMDATA" --user-agent "$DIP_USER_AGENT" "$DIP_LOGIN_URL" \
> "$DATADIR/dip_login_response.txt"

# Wait for a while to avoid problems with the site.

echo "$PROGNAME: Waiting for 5 seconds..." 1>&2
sleep 5

# Extract the link from the downloads page and access the actual resource.
# Look for a link of the form "ftp://user:pass@.../2012/mif25/..." in the page.
# Strip preceding and following text.
# Retain only the first, assuming that the latest is given first.

  wget -O - --load-cookies "$DIP_COOKIES" --user-agent "$DIP_USER_AGENT" "$DIP_RELEASE_URL" \
| tee "$DATADIR/dip_downloads_response.txt" \
| grep -e "ftp://$DIP_USERNAME:[^@]*@$DIP_HOST/[[:digit:]]\+/mif25/dip[[:digit:]]\+\.mif25\.gz" \
| sed -e 's/[^"]*"//' \
| sed -e 's/".*//' \
| head -n 1 \
> "$DATADIR/dip_download_url.txt"

DOWNLOAD_URL=`cat "$DATADIR/dip_download_url.txt"`
DOWNLOAD_FILE=${DOWNLOAD_URL##*/}

if [ "$VERBOSE" ]; then
    echo "$PROGNAME: URL: $DOWNLOAD_URL" 1>&2
fi

if [ "$CHECK_ONLY" ]; then
    if [ ! -e "$DATADIR/$DOWNLOAD_FILE" ]; then
        echo "$PROGNAME: Want to download file: $DOWNLOAD_FILE" 1>&2
    else
        echo "$DOWNLOAD_FILE"
    fi
else
    wget -O "$DATADIR/$DOWNLOAD_FILE" "$DOWNLOAD_URL" && echo "$DOWNLOAD_FILE"
    exit $?
fi
