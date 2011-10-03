#!/usr/bin/env python

"Parse UniProt text files."

import re

def parse_line(line):
    if not line:
        raise EOFError
    code, space, rest = line[:2], line[2:5], line[5:]
    if code != "//" and space != "   ":
        raise ValueError, "Line was not of the form 'code   data': %r" % line
    return code, rest.rstrip("\n")

class Parser:

    "A parser for UniProt text files."

    null = r"\N"
    date_regexp = re.compile(r"(\d{2})-([A-Z]{3})-(\d{4})")
    months = {}
    for i, name in enumerate(("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")):
        months[name] = i + 1

    def __init__(self, f, f_main, f_accessions):
        self.f = f
        self.f_main = f_main
        self.f_accessions = f_accessions
        self.line = None
        self.return_last = 0

    def close(self):
        if self.f is not None:
            self.f.close()
            self.f = None
        if self.f_main is not None:
            self.f_main.close()
            self.f_main = None
        if self.f_accessions is not None:
            self.f_accessions.close()
            self.f_accessions = None

    def next_line(self):
        if not self.return_last:
            self.line = parse_line(self.f.readline())
        else:
            self.return_last = 0
        return self.line

    def save_line(self):
        self.return_last = 1

    def parse_identifier(self, line):
        code, rest = line
        return rest.split()[0]

    def parse_accessions(self, line):
        code, rest = line
        l = self._get_accessions(rest)
        code, rest = self.next_line()
        while code == "AC":
            l += self._get_accessions(rest)
            code, rest = self.next_line()
        else:
            self.save_line()
        return l

    def _get_accessions(self, s):
        return [i.strip() for i in s.split(";") if i.strip()]

    def parse_dates(self, line):

        "See: http://web.expasy.org/docs/userman.html#DT_line"

        code, rest = line
        creation = self._get_date(rest) # creation date
        sequence = None
        code, rest = self.next_line()
        while code == "DT":
            if not sequence:
                sequence = self._get_date(rest)
            code, rest = self.next_line()
        else:
            self.save_line()
        return sequence or creation or self.null

    def _get_date(self, s):
        match = self.date_regexp.match(s)
        if match:
            day, month, year = match.groups()
            return "%s%02d%s" % (year, self.months[month], day)
        else:
            return None

    def parse_taxonomy(self, line):
        code, rest = line
        key, value = rest.rstrip(";").split("=")
        if key == "NCBI_TaxID":
            return value
        else:
            return None

    def parse_sequence(self, line):
        sequence = []
        code, rest = self.next_line()
        while code == "  ":
            sequence.append(rest)
            code, rest = self.next_line()
        else:
            self.save_line()
        return "".join(sequence).replace(" ", "")

    handlers = {
        "ID" : parse_identifier,
        "AC" : parse_accessions,
        "DT" : parse_dates,
        "OX" : parse_taxonomy,
        "SQ" : parse_sequence,
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
                    record[code] = handler(self, line)
        except EOFError:
            pass

    def write_record(self, record):
        record["AC1"] = record["AC"][0]
        self.f_main.write("%(ID)s\t%(AC1)s\t%(DT)s\t%(OX)s\t%(SQ)s\n" % record)
        for accession in record["AC"]:
            self.f_accessions.write("%s\t%s\n" % (record["ID"], accession))

if __name__ == "__main__":
    from os.path import extsep, join, split, splitext
    import sys, gzip

    progname = split(sys.argv[0])[-1]

    try:
        i = 1
        data_directory = sys.argv[i]
        filename = sys.argv[i+1]
    except IndexError:
        print >>sys.stderr, "Usage: %s <output data directory> <data file>" % progname
        sys.exit(1)

    basename, ext = splitext(split(filename)[-1])
    mainfile = join(data_directory, "%s_proteins%stxt" % (basename, extsep))
    accessionsfile = join(data_directory, "%s_accessions%stxt" % (basename, extsep))

    if ext.endswith("gz"):
        opener = gzip.open
    else:
        opener = open

    parser = Parser(opener(filename), open(mainfile, "w"), open(accessionsfile, "w"))
    try:
        parser.parse()
    finally:
        parser.close()

# vim: tabstop=4 expandtab shiftwidth=4
