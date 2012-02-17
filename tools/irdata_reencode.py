#!/usr/bin/env python

"""
Recode the contents of a file, writing a new file with a different encoding to
the original file.
"""

if __name__ == "__main__":
    from irdata.cmd import get_progname
    import sys, os, codecs

    progname = get_progname()

    try:
        infile, outfile, inencoding, outencoding, failencoding = sys.argv[1:6]
    except ValueError:
        print >>sys.stderr, "Usage: %s <input filename> <output filename> <input encoding> <output encoding> <failure encoding>" % progname
        sys.exit(1)

    f_in = open(infile)
    f_out = codecs.open(outfile, "w", encoding=outencoding)
    try:
        for lineno, line in enumerate(f_in.xreadlines()):
            try:
                uline = unicode(line, inencoding)
            except UnicodeError:
                print >>sys.stderr, "Encoding error on line %d." % (lineno + 1)
                uline = unicode(line, failencoding)
            f_out.write(uline)
    finally:
        f_out.close()
        f_in.close()

# vim: tabstop=4 expandtab shiftwidth=4
