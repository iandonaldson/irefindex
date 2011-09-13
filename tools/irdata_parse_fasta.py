#!/usr/bin/env python

"""
Parse FASTA format text files, writing protein flat files to the output data
directory.
"""

try:
    set
except NameError:
    from sets import Set as set

class Parser:

    "A parser for FASTA format text files."

    NULL = r"\N"

    def __init__(self, f, f_main, identifier_types):
        self.f = f
        self.f_main = f_main
        self.identifier_types = identifier_types

    def close(self):
        if self.f is not None:
            self.f.close()
            self.f = None
        if self.f_main is not None:
            self.f_main.close()
            self.f_main = None

    def parse_header(self, line):
        fields = line.rstrip("\n").lstrip(">").split("|")
        identifier_type = None
        identifiers = {}

        for field in fields:
            if not identifier_type:
                if field in self.identifier_types:
                    identifier_type = field
            else:
                identifiers[identifier_type] =  field
                identifier_type = None

        record = []
        for identifier_type in self.identifier_types:
            record.append(identifiers.get(identifier_type, self.NULL))
        return record

    def parse(self):
        record = []
        sequence = []
        for line in self.f.xreadlines():
            if line.startswith(">"):
                if record:
                    record.append("".join(sequence))
                    self.write_record(record)
                record = self.parse_header(line)
                sequence = []
            else:
                sequence.append(line.rstrip("\n"))
        else:
            if record:
                record.append("".join(sequence))
                self.write_record(record)

    def write_record(self, record):
        self.f_main.write("\t".join(record) + "\n")

if __name__ == "__main__":
    from os.path import extsep, join, split, splitext
    import sys, gzip

    progname = split(sys.argv[0])[-1]

    try:
        i = 1
        data_directory = sys.argv[i]
        identifier_types = sys.argv[i+1].split(",")
        filenames = sys.argv[i+2:]
    except IndexError:
        print >>sys.stderr, "Usage: %s <output data directory> <identifier types> <data file>..." % progname
        sys.exit(1)

    for filename in filenames:
        basename, ext = splitext(split(filename)[-1])
        print >>sys.stderr, "Parsing", basename

        if ext.endswith("gz"):
            opener = gzip.open
        else:
            opener = open

        f_out = open(join(data_directory, "%s_proteins.txt" % basename), "w")
        try:
            parser = Parser(opener(filename), f_out, identifier_types)
            try:
                parser.parse()
            finally:
                parser.close()
        finally:
            f_out.close()

# vim: tabstop=4 expandtab shiftwidth=4
