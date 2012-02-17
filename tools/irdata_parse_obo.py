#!/usr/bin/env python

"Extract term information from the PSI-MI ontology file."

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
                output = [id, line[6:]]
                print >>outfile, "\t".join(output)
            else:
                match = synonym_pattern.match(line)
                if match:
                    output = [id, match.group(1)]
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
