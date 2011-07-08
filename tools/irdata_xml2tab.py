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
    interactor

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

Participant properties are defined in terms of an interactor as part of an
interaction.
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
        # references    : property, reftype, id, dblabel, dbcode, reftypelabel, reftypecode
        "primaryRef"    : ("context", "element", "id", "db", "dbAc", "refType", "refTypeAc"), # also secondary and version
        "secondaryRef"  : ("context", "element", "id", "db", "dbAc", "refType", "refTypeAc"),
        # names         : property, nametype, label, code, value
        "shortLabel"    : ("context", "element", None, None, "content"),
        "fullName"      : ("context", "element", None, None, "content"),
        "alias"         : ("context", "element", "type", "typeAc", "content"),
        # organisms     : taxid
        "hostOrganism"  : ("ncbiTaxId",)
        }

    scopes = {
        "interaction"           : "interaction",
        "interactor"            : "interactor",
        "participant"           : "participant",
        "experimentDescription" : "experimentDescription",

        # PSI MI XML version 1.0 element mappings.

        "proteinInteractor"     : "interactor",
        "proteinParticipant"    : "participant",
        }

    def __init__(self, writer):
        EmptyElementParser.__init__(self)
        self.writer = writer

        # For PSI MI XML version 1.0 files without identifiers.

        self.identifiers = {
            "interaction"           : 0,
            "interactor"            : 0,
            "participant"           : 0,
            "experimentDescription" : 0
            }

    def get_scope(self):

        """
        Get the scope of the current path as the entity to which the current
        attributes and content belong.
        """

        for part in self.current_path[-1::-1]:
            if part in self.scopes.values():
                return part
        return None

    def characters(self, content):
        EmptyElementParser.characters(self, content.strip())

    def startElement(self, name, attrs):

        """
        Start an element, converting the element 'name' to a recognised scope if
        necessary, and adding an identifier to the 'attrs' if one is missing.
        """

        if self.scopes.has_key(name):
            name = self.scopes[name]
            if self.identifiers.has_key(name):

                # Handle PSI MI XML 1.0 identifiers which are absent.

                if not attrs.has_key("id"):
                    attrs = dict(attrs)
                    attrs["id"] = str(self.identifiers[name])
                    self.identifiers[name] += 1

        EmptyElementParser.startElement(self, name, attrs)

    def endElement(self, name):
        EmptyElementParser.endElement(self, self.scopes.get(name, name))

    def handleElement(self, content):

        "Handle a completed element with the given 'content'."

        element, parent, context, section = map(lambda x, y: x or y, self.current_path[-1:-5:-1], [None] * 4)
        attrs = dict(self.current_attrs[-1])

        # Get mappings from experiments to interactions.
        # The "ref" attribute is from PSI MI XML 1.0.

        if element == "experimentRef":
            if parent == "experimentList":
                self.writer.append((element, content or attrs["ref"], self.path_to_attrs["interaction"]["id"]))

        # And mappings from interactors to participants to interactions.
        # The "ref" attribute is from PSI MI XML 1.0.

        elif element == "interactorRef":
            if parent == "participant":
                self.writer.append((element, content or attrs["ref"], self.path_to_attrs["participant"]["id"], self.path_to_attrs["interaction"]["id"]))

        # Implicit interactor-to-participant mappings (applying only within participant elements).

        elif element == "interactor":
            if parent == "participant":
                self.writer.append((element, attrs["id"], self.path_to_attrs["participant"]["id"], self.path_to_attrs["interaction"]["id"]))

        # Implicit mappings applying only within an interaction scope.

        elif element == "experimentDescription":
            if self.path_to_attrs.has_key("interaction"):
                self.writer.append((element, attrs["id"], self.path_to_attrs["interaction"]["id"]))

        # Interactor organisms.

        elif element == "organism":
            if parent == "interactor":
                self.writer.append((element, parent, self.path_to_attrs["interactor"]["id"], attrs["ncbiTaxId"]))

        # Get other data.

        else:
            # Only consider supported elements.

            names = self.attribute_names.get(element)
            if not names:
                return

            # Exclude certain occurrences (as also done above).

            if context == "interactor" and section not in ("participant", "interactorList") or \
                context == "participant" and section != "participantList":
                return

            # Insist on a scope.

            scope = self.get_scope()
            if not scope:
                return

            # Gather together attributes.

            if content:
                attrs["content"] = content

            # Get the context, using a proper scope if appropriate.

            attrs["context"] = context
            attrs["element"] = element

            values = []
            for key in names:
                values.append(attrs.get(key))

            # Only write data for supported elements providing data.

            if not values:
                return

            # The parent indicates the data type as is only used to select the output file.

            self.writer.append((parent, scope, self.path_to_attrs[scope]["id"]) + tuple(values))

    def parse(self, filename):
        self.writer.start(filename)
        EmptyElementParser.parse(self, filename)

class Writer:

    "A simple writer of tabular data."

    filenames = (
        "experiment", "interactor",     # mappings
        "names", "xref", "organisms",   # properties
        )

    data_type_files = {
        "experimentRef"         : "experiment",
        "experimentDescription" : "experiment",
        "interactorRef"         : "interactor",
        "interactor"            : "interactor",
        "hostOrganismList"      : "organisms",
        "organism"              : "organisms",
        "names"                 : "names",
        "xref"                  : "xref",
        }

    def __init__(self, directory, source):
        self.directory = directory
        self.source = source
        self.files = {}
        self.filename = None

    def get_filename(self, key):
        return os.path.join(self.directory, "%s%stxt" % (key, os.path.extsep))

    def reset(self):
        for key in self.filenames:
            try:
                os.remove(self.get_filename(key))
            except OSError:
                pass

    def start(self, filename):
        self.filename = filename

        if not os.path.exists(self.directory):
            os.mkdir(self.directory)

        for key in self.filenames:
            self.files[key] = codecs.open(self.get_filename(key), "a", encoding="utf-8")

    def append(self, data):
        element = data[0]
        file = self.data_type_files[element]

        # Each record is prefixed with the source and filename.

        data = (self.source, self.filename) + data[1:]
        data = map(tab_to_space, data)
        data = map(bulkstr, data)
        print >>self.files[file], "\t".join(data)

    def close(self):
        for f in self.files.values():
            f.close()
        self.files = {}

if __name__ == "__main__":
    import sys

    progname = os.path.split(sys.argv[0])[-1]

    try:
        reset = sys.argv[1] == "--reset"
        i = reset and 2 or 1
        data_directory = sys.argv[i]
        source = sys.argv[i+1]
        filenames = sys.argv[i+2:]
    except IndexError:
        print >>sys.stderr, "Usage: %s [ --reset ] <data directory> <data source name> <data file>..." % progname
        sys.exit(1)

    writer = Writer(data_directory, source)
    if reset:
        writer.reset()

    parser = PSIParser(writer)
    try:
        for filename in filenames:
            parser.parse(filename)
    finally:
        writer.close()

# vim: tabstop=4 expandtab shiftwidth=4
