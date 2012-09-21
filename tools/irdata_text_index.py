#!/usr/bin/env python

"""
Index an input file for faster access to specific records.

This program scans a file and for each line occurring at the given interval,
a value identifying the line and the byte offset of the line is produced.

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

from irdata.data import RawImportFile, rewrite, index_for_int
from irdata.cmd import get_progname
from os.path import split, splitext
import sys, cmdsyntax, gzip

syntax_description = """
    --help |
    <interval> [ <filename> | - ] [ -f <field> ] [ -d <separator> ]
    """

if __name__ == "__main__":
    progname = get_progname()

    # Get the command line options.

    syntax = cmdsyntax.Syntax(syntax_description)
    try:
        matches = syntax.get_args(sys.argv[1:])
        args = matches[0]
    except IndexError:
        print >>sys.stderr, "Syntax:"
        print >>sys.stderr, syntax_description
        sys.exit(1)
    else:
        if args.has_key("help"):
            print >>sys.stderr, __doc__
            print >>sys.stderr, "Syntax:"
            print >>sys.stderr, syntax_description
            sys.exit(1)

    # Get the interval.

    interval = int(args["interval"])

    # Get the input stream.

    if args.has_key("filename"):
        infile = args["filename"]
        leafname = split(infile)[-1]
        basename, ext = splitext(leafname)
        if ext.endswith("gz"):
            opener = gzip.open
        else:
            opener = open
        f_in = opener(infile)
    else:
        f_in = sys.stdin

    # Get the field to be treated as the indexed term.

    if args.has_key("index"):
        field = index_for_int(args["index"])
    else:
        field = 0

    # Get the field separator.

    if args.has_key("separator"):
        separator = args["separator"]
    else:
        separator = "\t"

    try:
        pos = 0
        lineno = 0
        current_value = None
        current_value_start = None
        last_value = None

        writer = RawImportFile(rewrite(sys.stdout))

        while 1:
            line = f_in.readline()
            if not line:
                break

            value = line.split(separator)[field]

            # For new values, remember where they first appeared.

            if value != current_value:
                current_value = value
                current_value_start = pos

            # Emit the start of the current value region.

            if lineno % interval == 0 and current_value != last_value:
                writer.append((current_value, current_value_start))
                last_value = current_value

            lineno += 1
            pos += len(line)

    finally:
        if infile != "-":
            f_in.close()

# vim: tabstop=4 expandtab shiftwidth=4
