#!/usr/bin/env python

from irdata.signatures import *

if __name__ == "__main__":
    from os.path import extsep, split
    from os import rename
    import sys

    try:
        infile, outfile = sys.argv[1:3]
    except ValueError:
        print >>sys.stderr, "Usage: %s <sequences file> <signatures file>" % split(sys.argv[0])[-1]
        sys.exit(1)

    append = "--append" in sys.argv
    legacy = "--legacy" in sys.argv

    f = open(infile)
    out = open(outfile, "w")
    try:
        process_file(f, out, -1, ",", append, legacy)
    finally:
        out.close()
        f.close()

# vim: tabstop=4 expandtab shiftwidth=4
