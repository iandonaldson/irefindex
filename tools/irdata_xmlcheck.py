#!/usr/bin/env python

"""
A tool which checks XML files for well-formedness. Names of files that are not
well-formed are written to standard output, one per line.

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

from irdata.xmldata import Parser
from xml.sax import SAXException

if __name__ == "__main__":
    from irdata.cmd import get_progname
    import sys

    progname = get_progname()

    try:
        filenames = sys.argv[1:]
    except IndexError:
        print >>sys.stderr, "Usage: %s <data file>..." % progname
        sys.exit(1)

    have_exceptions = False
    parser = Parser()

    for filename in filenames:
        try:
            parser.parse(filename)
        except SAXException, exc:
            print >>sys.stderr, "%s: Parsing failed: %s" % (progname, exc)
            print filename
            have_exceptions = True

    sys.exit(have_exceptions and 1 or 0)

# vim: tabstop=4 expandtab shiftwidth=4
