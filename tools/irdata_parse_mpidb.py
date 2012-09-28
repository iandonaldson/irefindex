#!/usr/bin/env python

"""
Convert MPIDB MITAB files to standard MITAB format or to iRefIndex-compatible
data. Note that some fields contain multivalued data which should be expanded to
make multiple output lines for each input line, with each output line
representing an experiment.

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

from os.path import extsep, join, split, splitext
import os
import re
import gzip

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

all_fields = mpidb_fields

corresponding_fields = (
    "method", "authors", "pmids", "interactionType", "sourcedb",
    "interactionIdentifiers", "confidence"
    )

non_corresponding_fields = (
    "altA", "altB", "aliasA", "aliasB"
    )

list_fields = non_corresponding_fields + corresponding_fields

mpidb_term_regexp       = re.compile(r'(?P<prefix>.*?)"(?P<term>.*?)"\((?P<description>.*?)\)')
standard_term_regexp    = re.compile(r'(?P<term>.*?)\((?P<description>.*?)\)')
taxid_regexp            = re.compile(r'taxid:(?P<taxid>[^(]+)(\((?P<description>.*?)\))?')

term_regexps = mpidb_term_regexp, standard_term_regexp

class Parser:

    "A parser which produces output in different forms."

    def __init__(self, writer):
        self.writer = writer
        self.line_position = 0
        self.last_interaction = None

    def close(self):
        if self.writer is not None:
            self.writer.close()
            self.writer = None

    def parse(self, filename):

        """
        Parse the file with the given 'filename', writing to the output stream.
        """

        leafname = split(filename)[-1]
        basename, ext = splitext(leafname)

        if ext.endswith("gz"):
            opener = gzip.open
        else:
            opener = open

        f = opener(filename)

        try:
            self.writer.start(filename)

            # Skip the first line since it is a header.

            line = f.readline()
            line = f.readline()

            while line:
                self.parse_line(line)
                line = f.readline()

        finally:
            f.close()

    def parse_line(self, line):

        "Parse the given 'line', appending output to the writer."

        data = dict(zip(all_fields, line.strip().split("\t")))

        # Convert all list values into lists.

        for key in list_fields:
            data[key] = get_list(data[key], key in corresponding_fields)

        # Fix aliases.

        for key in ("aliasA", "aliasB"):
            data[key] = map(fix_alias, data[key])

        # Fix controlled vocabulary fields.

        for key in ("method", "interactionType", "sourcedb"):
            data[key] = map(fix_vocabulary_term, data[key])

        # Detect multi-line interactions.

        interaction = get_interaction(data)

        if interaction == self.last_interaction:
            self.line_position += 1
        else:
            self.line_position = 0
            self.last_interaction = interaction

        data["line_position"] = self.line_position

        self.writer.append(data)

class Writer:

    "Support for writing to files."

    def __init__(self, source, directory):
        self.input_source = source
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

        # Where no correspondences are being recorded, return the data as the
        # only experiment entry, and with only a single additional entry
        # indicating a unique output line number.

        if not corresponding_fields:
            data["line"] = self.output_line
            self.output_line += 1
            return [data]

        # Obtain the values for each of the fields.

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
        return join(self.directory, "mpidb_mitab.txt")

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
        "alternatives", "method", "authors", "pmids", "interactionType", "sourcedb", "interactionIdentifiers"
        )

    def init(self):
        self.files = {}

    def close(self):
        for f in self.files.values():
            f.close()
        self.files = {}

    def get_filename(self, key):
        return join(self.directory, "mitab_%s%stxt" % (key, extsep))

    def start(self, filename):
        Writer.start(self, filename)

        # Use the filename for specific MPIDB sources.

        if self.input_source == "MPIDB":
            self.source = split(filename)[-1]
        else:
            self.source = self.input_source

        if self.files:
            return

        if not os.path.exists(self.directory):
            os.mkdir(self.directory)

        for key in self.filenames:
            self.files[key] = open(self.get_filename(key), "w")

    def append(self, data):

        "Write iRefIndex-compatible output from the 'data'."

        # Interactor-specific records.

        positionA = data["line_position"]
        positionB = data["line_position"] + 1

        # Only write the principal interactor of multi-line interactions once.

        if positionA == 0:
            self.write_line(self.files["uid"], (self.source, self.filename, get_interaction(data), positionA) + split_uid(data["uidA"]) + (split_taxid(data["taxA"])[0],))
        self.write_line(self.files["uid"], (self.source, self.filename, get_interaction(data), positionB) + split_uid(data["uidB"]) + (split_taxid(data["taxB"])[0],))

        for filename, fields in (
            ("alternatives", ("altA", "altB")),
            ("alias", ("aliasA", "aliasB"))
            ):
            for position, key in enumerate(fields):
                for entry, s in enumerate(data[key]):
                    if not s:
                        continue
                    prefix, value = split_value(s)

                    # Only write the details of the principal interactor once.

                    if position != 0 or positionA == 0:
                        self.write_line(self.files[filename], (self.source, self.filename, get_interaction(data), positionA + position, prefix, value, entry))

        # Experiment-specific records.

        if positionA == 0:
            self.append_lists(self.get_experiment_data(data))

    def append_lists(self, list_data):
        for entry, data in enumerate(list_data):
            for key in ("authors",):
                for s in data[key]:
                    self.write_line(self.files[key], (self.source, self.filename, data["line"], get_interaction(data), s, entry))

            for key in ("method", "interactionType", "sourcedb"):
                for s in data[key]:
                    term, description = split_vocabulary_term(s)
                    self.write_line(self.files[key], (self.source, self.filename, data["line"], get_interaction(data), term, description, entry))

            for key in ("pmids",):
                for s in data[key]:
                    prefix, value = split_value(s)
                    self.write_line(self.files[key], (self.source, self.filename, data["line"], get_interaction(data), value, entry))

            for key in ("interactionIdentifiers",):
                for s in data[key]:
                    prefix, value = split_value(s)
                    self.write_line(self.files[key], (self.source, self.filename, data["line"], get_interaction(data), prefix, value, entry))

def get_interaction(data):
    return data.get("interaction") or split_value(data["interactionIdentifiers"][0])[-1]

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
    for regexp in term_regexps:
        match = regexp.match(s)
        if match:
            return "%s(%s)" % (match.group("term"), match.group("description"))
    raise ValueError, "Term %r is not well-formed." % s

def fix_alias(s):
    if s.startswith("uniprotkb:"):
        prefix, symbol = s.split(":")[:2]
        return "entrezgene/locuslink:" + symbol
    else:
        return s

def split_value(s):
    parts = s.split(":", 1)
    return tuple(parts)

def split_vocabulary_term(s):
    for regexp in term_regexps:
        match = regexp.match(s)
        if match:
            return (match.group("term"), match.group("description"))
    raise ValueError, "Term %r is not well-formed." % s

def split_uid(s):
    uids = get_list(s, False)
    return split_value(uids[-1]) # NOTE: Hack for InnateDB MITAB.

def split_taxid(s):
    match = taxid_regexp.match(s)
    if match:
        return (match.group("taxid"), match.group("description"))
    else:
        raise ValueError, "Taxonomy %r is not well-formed." % s

if __name__ == "__main__":
    from irdata.cmd import get_progname
    import sys

    progname = get_progname()

    try:
        source = sys.argv[1]
        directory = sys.argv[2]
        filenames = sys.argv[3:]
    except IndexError:
        print >>sys.stderr, "Usage: %s <source> <output data directory> <filename>..." % progname
        sys.exit(1)

    # Redefine the corresponding multivalued fields according to the mode.

    if not source.startswith("MPI-"):
        corresponding_fields = ()
        all_fields = standard_fields

    writer = iRefIndexWriter(source, directory)

    parser = Parser(writer)
    try:
        for filename in filenames:
            parser.parse(filename)
    finally:
        parser.close() # closes the writer

# vim: tabstop=4 expandtab shiftwidth=4
