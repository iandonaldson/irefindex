#!/usr/bin/env python

"""
Parse the table embedded in the UniProt FlyBase and Yeast text files.
"""

import re

class Parser:

    "A parser for UniProt FlyBase and Yeast format text files."

    NULL = r"\N"
    NO_RECORD, CONTINUE, END = 0, 1, 2
    column_pattern = re.compile(r"(\s+)")

    def __init__(self, f, f_out, f_log, filetype):
        self.f = f
        self.f_out = f_out
        self.f_log = f_log
        self.filetype = filetype
        self.columns = None
        self.lineno = None

    def init_columns(self, line):
        columns = []
        boundaries = []
        regions = iter(self.column_pattern.split(line))

        try:
            i = 0
            while 1:
                region = regions.next()
                j = i + len(region)
                columns.append((i, j))
                region = regions.next()
                i = j + len(region)
                boundaries.append((j, i))
        except StopIteration:
            pass

        self.columns = columns
        self.boundaries = boundaries

    def split_line(self, line, regions):
        return [line[start:end].strip() for (start, end) in regions]

    def get_specified(self, values):
        return len([value for value in values if value])

    def get_values(self, line, continuation=None):

        # Split the line into columns and determine whether a record is present.

        values = self.split_line(line, self.columns)
        specified = self.get_specified(values)

        # If the boundaries between cells contain text, the end of the table may
        # have been reached.

        boundaries = self.split_line(line, self.boundaries)
        overflows = self.get_specified(boundaries)

        if overflows:
            self.write_log("SERIOUS", "Table cell overflow occurred.")

        if not continuation and specified < 2:
            return None, self.NO_RECORD

        # Handle compound columns in FlyBase.

        if self.filetype == "fly":
            values[2:3] = values[2].split()
            self.write_record(values)
            return None, self.END

        # Handle compound values in Yeast.

        elif self.filetype == "yeast":
            if continuation:
                continuation[0] += " " + values[0]
            else:
                continuation = values

            if continuation[0].endswith(";"):
                return continuation, self.CONTINUE
            else:
                for value in continuation[0].split("; "):
                    self.write_record([value] + continuation[1:])
                return None, self.END

        else:
            return None, self.END

    def parse(self):
        values = None

        for self.lineno, line in enumerate(self.f.xreadlines()):
            line = line.rstrip("\n")

            # Get the column dimensions.

            if not self.columns:
                if line.startswith("__"):
                    self.init_columns(line)

            # With column dimensions, get values and the status of each record
            # as new lines are read.

            else:
                values, status = self.get_values(line, values)

    def write_record(self, record):
        self.f_out.write("\t".join(record) + "\n")

    def write_log(self, level, message):
        self.f_log.write("%d: %s: %s\n" % (self.lineno, level, message))

if __name__ == "__main__":
    from os.path import split
    import sys

    progname = split(sys.argv[0])[-1]

    try:
        filetype = sys.argv[1]
    except IndexError:
        print >>sys.stderr, "Usage: %s ( fly | yeast )" % progname
        sys.exit(1)

    parser = Parser(sys.stdin, sys.stdout, sys.stderr, filetype)
    parser.parse()

# vim: tabstop=4 expandtab shiftwidth=4
