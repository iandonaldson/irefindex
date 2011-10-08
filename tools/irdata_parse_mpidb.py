#!/usr/bin/env python

"""
Convert MPIDB MITAB files to standard MITAB format or to iRefIndex-compatible
data. Note that some fields contain multivalued data which should be expanded to
make multiple output lines for each input line, with each output line
representing an experiment.
"""

import os
import re

standard_fields = (
    "uidA", "uidB",
    "altA", "altB",
    "aliasA", "aliasB",
    "method",
    "authors",
    "pmids",
    "taxA", "taxB",
    "interactionType",
    "sourcedb",
    "interactionIdentifiers",
    "confidence"
    )

mpidb_fields = standard_fields + (
    "evidence",
    "interaction"
    )

corresponding_fields = (
    "method", "authors", "pmids", "interactionType", "sourcedb",
    "interactionIdentifiers", "confidence"
    )

non_corresponding_fields = (
    "altA", "altB", "aliasA", "aliasB"
    )

list_fields = non_corresponding_fields + corresponding_fields

mpidb_term_regexp = re.compile(r'(?P<prefix>.*?)"(?P<term>.*?)"\((?P<description>.*?)\)')
standard_term_regexp = re.compile(r'(?P<term>.*?)\((?P<description>.*?)\)')

class Parser:

    "A parser which produces output in different forms."

    def __init__(self, writer):
        self.writer = writer

    def close(self):
        if self.writer is not None:
            self.writer.close()
            self.writer = None

    def parse(self, filename):

        """
        Parse the file with the given 'filename', writing to the output stream.
        """

        f = open(filename)

        try:
            self.writer.start(filename)

            first = 1
            for line in f.xreadlines():

                # Skip the first line since it is a header.

                if first:
                    first = 0
                    continue

                self.parse_line(line)

        finally:
            f.close()

    def parse_line(self, line):

        "Parse the given 'line', writing to the 'out' stream."

        data = dict(zip(mpidb_fields, line.strip().split("\t")))

        # Convert all list values into lists.

        for key in list_fields:
            data[key] = get_list(data[key], key in corresponding_fields)

        # Remove alternatives.

        for key in ("altA", "altB"):
            data[key] = []

        # Fix aliases.

        for key in ("aliasA", "aliasB"):
            data[key] = map(fix_alias, data[key])

        # Fix controlled vocabulary fields.

        for key in ("method", "interactionType", "sourcedb"):
            data[key] = map(fix_vocabulary_term, data[key])

        self.writer.append(data)

class Writer:

    "Support for writing to files."

    def __init__(self, directory):
        self.directory = directory
        self.filename = None
        self.init()

    def start(self, filename):
        self.filename = filename
        self.output_line = 1

    def write_line(self, out, values):
        print >>out, "\t".join(map(str, values))

    def get_experiment_data(self, data):

        "Observe correspondences between multivalued fields in 'data'."

        fields = []
        length = None
        for key in corresponding_fields:
            values = data[key]

            # Ensure a consistent length for all fields.

            if length is None:
                length = len(values)
            elif length != len(values):
                raise ValueError, "Field %s has %d values but preceding fields have %d values." % (key, len(values), length)

            fields.append(values)

        # Get values for the fields for each position in the correspondence.

        experiment_data = []

        for values in zip(*fields):
            new_data = {"line" : self.output_line}
            for key, value in zip(corresponding_fields, values):
                new_data[key] = [value]

            # Write the unpacked correspondences.

            experiment_data.append(new_data)
            self.output_line += 1

        return experiment_data

class MITABWriter(Writer):

    "A standard MITAB format file writer."

    def init(self):
        self.out = None

    def close(self):
        if self.out is not None:
            self.out.close()
            self.out = None

    def get_filename(self):
        return os.path.join(self.directory, "mpidb_mitab.txt")

    def start(self, filename):
        Writer.start(self, filename)

        if self.out is not None:
            return

        if not os.path.exists(self.directory):
            os.mkdir(self.directory)

        self.out = open(self.get_filename(), "w")
        print >>self.out, "#" + "\t".join(standard_fields)

    def append(self, data):

        "Write tidied MITAB from the given 'data'."

        for exp_data in self.get_experiment_data(data):
            new_data = {}
            new_data.update(data)
            new_data.update(exp_data)

            # Convert values back into strings.

            for key in list_fields:
                new_data[key] = get_string(new_data[key])

            self.write_line(self.out, [new_data[key] for key in standard_fields])

class iRefIndexWriter(Writer):

    "A writer for iRefIndex-compatible data."

    filenames = (
        "uid", "alias", # collecting more than one column each
        "method", "authors", "pmids", "interactionType", "sourcedb", "interactionIdentifiers"
        )

    def init(self):
        self.files = {}

    def close(self):
        for f in self.files.values():
            f.close()
        self.files = {}

    def get_filename(self, key):
        return os.path.join(self.directory, "mitab_%s%stxt" % (key, os.path.extsep))

    def start(self, filename):
        Writer.start(self, filename)

        if self.files:
            return

        self.source = os.path.split(filename)[-1]

        if not os.path.exists(self.directory):
            os.mkdir(self.directory)

        for key in self.filenames:
            self.files[key] = open(self.get_filename(key), "w")

    def append(self, data):

        "Write iRefIndex-compatible output from the 'data'."

        experiment_data = self.get_experiment_data(data)

        # Interactor-specific records.

        self.write_line(self.files["uid"], (self.source, self.filename, data["interaction"], "0") + split_value(data["uidA"]) + (split_value(data["taxA"])[1],))
        self.write_line(self.files["uid"], (self.source, self.filename, data["interaction"], "1") + split_value(data["uidB"]) + (split_value(data["taxB"])[1],))

        for position, key in enumerate(("aliasA", "aliasB")):
            for entry, s in enumerate(data[key]):
                prefix, value = split_value(s)
                self.write_line(self.files["alias"], (self.source, self.filename, data["interaction"], position, prefix, value, entry))

        # Experiment-specific records.

        for entry, exp_data in enumerate(experiment_data):
            for key in ("authors",):
                for s in exp_data[key]:
                    self.write_line(self.files[key], (self.source, self.filename, exp_data["line"], data["interaction"], s, entry))

            for key in ("method", "interactionType", "sourcedb"):
                for s in exp_data[key]:
                    term, description = split_vocabulary_term(s)
                    self.write_line(self.files[key], (self.source, self.filename, exp_data["line"], data["interaction"], term, description, entry))

            for key in ("pmids",):
                for s in exp_data[key]:
                    prefix, value = split_value(s)
                    self.write_line(self.files[key], (self.source, self.filename, exp_data["line"], data["interaction"], value, entry))

            for key in ("interactionIdentifiers",):
                for s in exp_data[key]:
                    prefix, value = split_value(s)
                    self.write_line(self.files[key], (self.source, self.filename, exp_data["line"], data["interaction"], prefix, value, entry))

# Value processing.

def get_list(s, preserve_length):
    l = s.split("|")
    if preserve_length:
        return [(i != "-" and i or "") for i in l]
    else:
        return [i for i in l if i != "-"]

def get_string(l):
    if not l:
        return "-"
    else:
        return "|".join(l)

def fix_vocabulary_term(s):
    match = mpidb_term_regexp.match(s)
    if not match:
        raise ValueError, "Term %r is not well-formed." % s
    else:
        return "%s(%s)" % (match.group("term"), match.group("description"))

def fix_alias(s):
    if s.startswith("uniprotkb:"):
        prefix, symbol = s.split(":")[:2]
        return "entrezgene/locuslink:" + symbol
    else:
        return s

def split_value(s):
    parts = s.split(":")
    return parts[0], ":".join(parts[1:])

def split_vocabulary_term(s):
    match = standard_term_regexp.match(s)
    if not match:
        raise ValueError, "Term %r is not well-formed." % s
    else:
        return (match.group("term"), match.group("description"))

if __name__ == "__main__":
    import sys

    progname = os.path.split(sys.argv[0])[-1]

    try:
        directory = sys.argv[1]
        filenames = sys.argv[2:]
    except IndexError:
        print >>sys.stderr, "Usage: %s <output data directory> <filename>..." % progname
        sys.exit(1)

    writer = iRefIndexWriter(directory)

    parser = Parser(writer)
    try:
        for filename in filenames:
            parser.parse(filename)
    finally:
        parser.close() # closes the writer

# vim: tabstop=4 expandtab shiftwidth=4
