#!/usr/bin/env python

"""
A tool which reads PSI MI XML files and produces tabular data.

PSI MI XML files can provide separate experiment, interaction and interactor
lists:

  experimentList
    experimentDescription
  interactionList
    interaction
      experimentList
        experimentRef -> experimentDescription/@id
      participantList
        participant
          interactorRef -> interactor/@id
  interactorList

Or such files can provide interaction lists containing experiment and interactor
details:

  interactionList
    interaction
      experimentList
        experimentDescription
      participantList
        participant
          interactor

When processing both kinds of files, properties of each data type can be
captured as they are read. The current interaction identifier must be retained
in order to document the relationships between interactions and the other data
types.

For the first kind of file, interaction relationships to experiments and
interactors are explicitly given in "*Ref" elements. For the second kind of
file, such relationships are implicit when an experiment or interactor is
included within an interaction.
"""

from irdata.data import *
import xml.sax
import os

class Parser(xml.sax.handler.ContentHandler):

    "A generic parser."

    def __init__(self):
        self.current_path = []
        self.current_attrs = []
        self.path_to_attrs = {}

    def startElement(self, name, attrs):
        self.current_path.append(name)
        self.current_attrs.append(attrs)
        self.path_to_attrs[name] = attrs

    def endElement(self, name):
        name = self.current_path.pop()
        self.current_attrs.pop()
        del self.path_to_attrs[name]

    def parse(self, filename):

        """
        Parse the file with the given 'filename'.
        """

        f = open(filename, "rb")
        try:
            parser = xml.sax.make_parser()
            parser.setContentHandler(self)
            parser.setErrorHandler(xml.sax.handler.ErrorHandler())
            parser.setFeature(xml.sax.handler.feature_external_ges, 0)
            parser.parse(f)
        finally:
            f.close()

class EmptyElementParser(Parser):

    """
    A parser which calls the handleElement method with an empty string for empty
    elements.
    """

    def __init__(self):
        Parser.__init__(self)
        self.current_chars = {}

    def endElement(self, name):
        current_path = tuple(self.current_path)
        if not self.current_chars.has_key(current_path):
            self.handleElement("")
        else:
            self.handleElement(self.current_chars[current_path])
            del self.current_chars[current_path]
        Parser.endElement(self, name)

    def characters(self, content):
        current_path = tuple(self.current_path)
        if not self.current_chars.has_key(current_path):
            self.current_chars[current_path] = content
        else:
            self.current_chars[current_path] += content

class PSIParser(EmptyElementParser):

    """
    A class which records the properties and relationships in PSI MI XML files.
    """

    attribute_names = {
        "primaryRef"    : ("id", "db", "dbAc", "refType", "refTypeAc"), # also secondary and version
        "secondaryRef"  : ("id", "db", "dbAc", "refType", "refTypeAc"),
        "shortLabel"    : ("content",),
        "fullName"      : ("content",),
        "alias"         : ("type", "typeAc", "content"),
        "hostOrganism"  : ("ncbiTaxId",),
        }

    def __init__(self, writer):
        EmptyElementParser.__init__(self)
        self.writer = writer

    def get_scope(self):
        n = len(self.current_path)
        for i in xrange(-1, -n-1, -1):
            part = self.current_path[i]
            if part in ("experimentDescription", "interaction", "interactor"):
                return part
        return None

    def characters(self, content):
        EmptyElementParser.characters(self, content.strip())

    def handleElement(self, content):
        element = self.current_path[-1]
        attrs = dict(self.current_attrs[-1])

        # Get mappings from experiments and interactors to interactions.
        # Explicit mappings.

        if element in ("experimentRef", "interactorRef"):
            self.writer.append((element, content, self.path_to_attrs["interaction"]["id"]))

        # Implicit mappings only within interaction elements.

        elif element in ("experimentDescription", "interactor"):
            if self.path_to_attrs.has_key("interaction"):
                self.writer.append((element, self.current_attrs[-1]["id"], self.path_to_attrs["interaction"]["id"]))

        # Get other data.

        else:
            scope = self.get_scope()
            if scope:
                context = self.current_path[-3]
                data_type = self.current_path[-2]
                names = self.attribute_names.get(element)
                if content:
                    attrs["content"] = content
                if names and attrs:
                    values = []
                    for key in names:
                        values.append(attrs.get(key))
                    self.writer.append((data_type, scope, self.path_to_attrs[scope]["id"], context, element) + tuple(values))

    def parse(self, filename):
        self.writer.start()
        EmptyElementParser.parse(self, filename)

class Writer:

    "A simple writer of tabular data."

    filenames = (
        "experiment", "interactor",     # mappings
        "names", "xref", "organisms",   # properties
        )

    element_files = {
        "experimentRef"         : "experiment",
        "experimentDescription" : "experiment",
        "interactorRef"         : "interactor",
        "interactor"            : "interactor",
        "hostOrganismList"      : "organisms",
        "names"                 : "names",
        "xref"                  : "xref",
        }

    def __init__(self, directory):
        self.directory = directory
        self.files = {}

    def close(self):
        for f in self.files.values():
            f.close()
        self.files = {}

    def start(self):
        if not os.path.exists(self.directory):
            os.mkdir(self.directory)

        for key in self.filenames:
            self.files[key] = codecs.open(os.path.join(self.directory, "%s%stxt" % (key, os.path.extsep)), "w", encoding="utf-8")

    def append(self, data):
        element = data[0]
        file = self.element_files[element]
        print >>self.files[file], "\t".join(map(bulkstr, data[1:]))

if __name__ == "__main__":
    import sys

    progname = os.path.split(sys.argv[0])[-1]

    try:
        filename = sys.argv[1]
    except IndexError:
        print >>sys.stderr, "Usage: %s <data file>" % progname
        sys.exit(1)

    writer = Writer(len(sys.argv) > 2 and sys.argv[2] or "data")
    parser = PSIParser(writer)
    try:
        parser.parse(filename)
    finally:
        writer.close()

# vim: tabstop=4 expandtab shiftwidth=4
