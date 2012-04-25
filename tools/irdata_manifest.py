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

def to_string(nodes):

    "Join all text descendants of the first of the given 'nodes'."

    return " ".join([n.nodeValue for n in nodes[0].xpath(".//text()")]).strip()

def first_word(value, sep=None):

    "Extract the first word from the given 'value'."

    return value.strip().split(sep)[0]

def last_word(value, sep=None):

    "Extract the last word from the given 'value'."

    return value.strip().split(sep)[-1]

def first_line(value):

    "Extract the first line from the given 'value'."

    return first_word(value, "\n")

def identity(value):

    "Return the presented 'value'."

    return value

def strip_brackets(value):

    "Remove brackets around 'value'."

    return value.strip("()")

filters = {
    "to_string" : to_string,
    "first_word" : first_word,
    "last_word" : last_word,
    "first_line" : first_line,
    "identity" : identity,
    "strip_brackets" : strip_brackets,
    }

if __name__ == "__main__":
    from irdata.cmd import get_progname
    import sys, os

    progname = get_progname()

    if len(sys.argv) < 2:
        print >>sys.stderr, "Usage: %s <url>" % progname
        sys.exit(1)

    url = sys.argv[1]

    try:
        d = libxml2dom.parseURI(url, html=True)

        for line in sys.stdin.readlines():
            name, filter_list, path = line.strip().split("\t")
            value = d.xpath(path)
            for filter in filter_list.split(","):
                filter = filters[filter]
                value = filter(value)
            print >>sys.stdout, "%s\t%s" % (name, value)

    except Exception, exc:
        print >>sys.stderr, "%s: Manifest retrieval failed with exception: %s" % (progname, exc)
        sys.exit(1)

# vim: tabstop=4 expandtab shiftwidth=4
