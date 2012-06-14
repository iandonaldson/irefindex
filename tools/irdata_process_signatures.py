#!/usr/bin/env python

"""
Process protein sequences to make signatures/digests.

--------

Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
Original author: Paul Boddie <paul.boddie@biotek.uio.no>

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

from irdata.signatures import *

if __name__ == "__main__":
    from os.path import extsep, split
    from os import rename
    import sys

    try:
        infile, outfile = sys.argv[1:3]
    except ValueError:
        print >>sys.stderr, """\
Usage: %s <sequences file> <signatures file> [ --append ] [ --append-length ] [ --legacy ]""" % split(sys.argv[0])[-1]
        sys.exit(1)

    append = "--append" in sys.argv
    append_length = "--append-length" in sys.argv
    legacy = "--legacy" in sys.argv

    f = open(infile)
    out = open(outfile, "w")
    try:
        process_file(f, out, -1, ",", append, append_length, legacy)
    finally:
        out.close()
        f.close()

# vim: tabstop=4 expandtab shiftwidth=4
