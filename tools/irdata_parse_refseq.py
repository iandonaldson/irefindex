#!/usr/bin/env python

"""
Parse RefSeq text files.

Various NCBI resources use the "feature table" format documented here:

ftp://ftp.ncbi.nlm.nih.gov/genbank/docs/FTv9_0.html
"""

import re

def parse_line(line):
    if not line:
        raise EOFError
    parts = re.split(r"(\s+)", line)

    if parts:

        # First field is not empty.

        if parts[0]:
            code = parts[0]
            rest = "".join(parts[2:])

        # First field is empty.

        else:
            code = None
            rest = "".join(parts[2:])

        return code, rest.rstrip("\n")
    else:
        return None, None

class Parser:

    "A parser for UniProt text files."

    taxid_regexp = re.compile('/db_xref="taxon:(.*?)"')

    def __init__(self, f, f_main):
        self.f = f
        self.f_main = f_main
        self.line = None
        self.return_last = 0

    def close(self, both=False):
        if self.f is not None:
            self.f.close()
            self.f = None
        if both and self.f_main is not None:
            self.f_main.close()
            self.f_main = None

    def next_line(self):
        if not self.return_last:
            self.line = parse_line(self.f.readline())
        else:
            self.return_last = 0
        return self.line

    def save_line(self):
        self.return_last = 1

    def parse_accession(self, line, record):
        code, rest = line
        record[code] = rest

    def parse_version(self, line, record):
        code, rest = line
        version, gi = rest.split()
        record["VERSION"] = version
        record["GI"] = gi.split(":")[1] # strip "GI:" from the identifier

    def parse_features(self, line, record):
        code, rest = self.next_line()
        while not code:
            match = self.taxid_regexp.match(rest)
            if match:
                record["TAXID"] = match.group(1)
                return
            code, rest = self.next_line()
        else:
            self.save_line()

    def parse_origin(self, line, record):
        sequence = []
        code, rest = self.next_line()
        while not code:
            rest = "".join(rest.strip().split()[1:])
            sequence.append(rest)
            code, rest = self.next_line()
        else:
            self.save_line()
        record["SEQUENCE"] = "".join(sequence).upper()

    handlers = {
        "ACCESSION" : parse_accession,
        "FEATURES" : parse_features,
        "ORIGIN" : parse_origin,
        "VERSION" : parse_version,
        }

    def parse(self):
        record = {}
        try:
            while 1:
                line = self.next_line()
                code, rest = line
                if code == "//":
                    self.write_record(record)
                    record = {}
                handler = self.handlers.get(code)
                if handler is not None:
                    handler(self, line, record)
        except EOFError:
            pass

    def write_record(self, record):
        self.f_main.write("%(ACCESSION)s\t%(VERSION)s\t%(GI)s\t%(TAXID)s\t%(SEQUENCE)s\n" % record)

if __name__ == "__main__":
    from os.path import extsep, join, split, splitext
    import sys, gzip

    progname = split(sys.argv[0])[-1]

    try:
        i = 1
        data_directory = sys.argv[i]
        filenames = sys.argv[i+1:]
    except IndexError:
        print >>sys.stderr, "Usage: %s <output data directory> <data file>..." % progname
        sys.exit(1)

    f_out = open(join(data_directory, "refseq_proteins.txt"), "w")
    try:
        for filename in filenames:
            leafname = split(filename)[-1]
            basename, ext = splitext(leafname)
            print >>sys.stderr, "Parsing", leafname

            if ext.endswith("gz"):
                opener = gzip.open
            else:
                opener = open

            parser = Parser(opener(filename), f_out)
            try:
                parser.parse()
            finally:
                parser.close()
    finally:
        f_out.close()

# vim: tabstop=4 expandtab shiftwidth=4
