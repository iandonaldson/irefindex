#!/usr/bin/env python

"""
Split an input file into self-contained pieces for parallel processing.

This program finds suitable offsets within a file at which processing can
safely occur. Using an input interval, the program seeks to multiples of the
interval and then attempts to find the next record terminator. Upon finding the
terminator and thus the start of the next record, the end of a segment can be
defined along with the beginning of the next segment.

Each segment is emitted in a tab-separated form as follows:

<start> <length>

Record terminators are newlines by default, and if explicitly specified, they
must be whole line records.

--------

Copyright (C) 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
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
    from os.path import split, splitext
    import sys, gzip

    progname = get_progname()

    try:
        one_based = sys.argv[1] == "-1"
        i = one_based and 2 or 1
        interval, infile = sys.argv[i:i+2]
        interval = int(interval)
        if len(sys.argv) >= i+3:
            record_terminator = sys.argv[i+2]
        else:
            record_terminator = ""
    except (IndexError, ValueError):
        print >>sys.stderr, """\
Usage: %s [ -1 ] <interval> <input filename> [ <record terminator> ]

Example: %s 10000 uniprot_sprot.dat '//'
    """ % (progname, progname)
        sys.exit(1)

    leafname = split(infile)[-1]
    basename, ext = splitext(leafname)

    if infile == "-":
        f_in = sys.stdin
    else:
        if ext.endswith("gz"):
            opener = gzip.open
        else:
            opener = open
        f_in = opener(infile)

    try:
        # The start of the file is always a viable starting point.

        start = 0
        pos = interval

        while 1:
            f_in.seek(pos)

            line = f_in.readline()
            pos += len(line)

            # Handle the end of the file.

            if not line:

                # Check to see if the last start position was at the end of the
                # file.

                f_in.seek(start)

                if f_in.readline():
                    print one_based and (start + 1) or start

                break

            while record_terminator and line.rstrip("\n") != record_terminator:
                line = f_in.readline()
                pos += len(line)
                if not line:
                    print one_based and (start + 1) or start
                    break

            print one_based and (start + 1) or start, pos - start
            start = pos
            pos += interval

    finally:
        if infile != "-":
            f_in.close()

# vim: tabstop=4 expandtab shiftwidth=4
