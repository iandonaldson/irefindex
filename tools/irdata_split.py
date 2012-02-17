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
