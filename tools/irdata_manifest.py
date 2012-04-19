#!/usr/bin/env python

"""
Obtain manifest information from the Web sites of various data sources.

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

import libxml2dom

def to_string(node):
    return " ".join([n.nodeValue for n in node[0].xpath(".//text()")]).strip()

def first_line(node):
    return "".join([n.nodeValue for n in node[0].xpath(".//text()")]).strip().split("\n")[0]

def identity(value):
    return value

filters = {
    "to_string" : to_string,
    "first_line" : first_line,
    "identity" : identity,
    }

if __name__ == "__main__":
    from irdata.cmd import get_progname
    import sys, os

    progname = get_progname()

    if len(sys.argv) < 2:
        print >>sys.stderr, "Usage: %s <url>" % progname
        sys.exit(1)

    url = sys.argv[1]
    d = libxml2dom.parseURI(url, html=True)

    for line in sys.stdin.readlines():
        name, filter, path = line.strip().split("\t")
        filter = filters[filter]
        print >>sys.stdout, "%s\t%s" % (name, filter(d.xpath(path)))

# vim: tabstop=4 expandtab shiftwidth=4
