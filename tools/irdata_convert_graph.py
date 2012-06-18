#!/usr/bin/env python

"""
Convert the iRefScape graph edge data to a Java serialised object
representation.

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

if __name__ == "__main__":
    from irdata.cmd import get_progname
    from irdata.java import dump_pairs
    import sys

    progname = get_progname()

    try:
        infile, outfile = sys.argv[1:6]
    except ValueError:
        print >>sys.stderr, "Usage: %s <input filename> <output filename>" % progname
        sys.exit(1)

    f_in = open(infile)
    f_out = open(outfile, "wb")
    try:
        pairs = []
        for line in f_in.xreadlines():
            line = line.rstrip()
            pairs.append(map(int, line.split("\t")))
        dump_pairs(pairs, f_out)
    finally:
        f_out.close()
        f_in.close()

# vim: tabstop=4 expandtab shiftwidth=4
