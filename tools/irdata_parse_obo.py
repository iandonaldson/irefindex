#!/usr/bin/env python

"""
Extract term information from the PSI-MI ontology file.

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

import re

synonym_pattern = re.compile(r'synonym: "(.*?)" EXACT')

def parse(infile, outfile):
    state = None
    id = None

    line = infile.readline()

    while line:
        line = line.rstrip("\n")

        if line.startswith("[Term]"):
            state = "TERM"

        elif state == "TERM" and line.startswith("id: "):
            state = "ID"
            id = line[4:]

        elif state == "ID":
            if line.startswith("name: "):
                output = [id, line[6:], 'preferred']
                print >>outfile, "\t".join(output)
            else:
                match = synonym_pattern.match(line)
                if match:
                    output = [id, match.group(1), 'synonym']
                    print >>outfile, "\t".join(output)

        elif not line.strip():
            state = None

        line = infile.readline()

if __name__ == "__main__":
    from irdata.cmd import get_progname
    from os.path import join, split
    import sys

    progname = get_progname()

    try:
        i = 1
        data_directory = sys.argv[i]
        filename = sys.argv[i+1]
    except IndexError:
        print >>sys.stderr, "Usage: %s <output data directory> <data file>" % progname
        sys.exit(1)

    leafname = split(filename)[-1]

    if filename == "-":
        print >>sys.stderr, "Parsing standard input"
        f = sys.stdin
    else:
        print >>sys.stderr, "Parsing", leafname
        f = open(filename)

    f_out = open(join(data_directory, "terms"), "w")

    try:
        parse(f, f_out)
    finally:
        if filename != "-":
            f.close()
        f_out.close()

# vim: tabstop=4 expandtab shiftwidth=4
