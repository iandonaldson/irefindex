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
interaction. Participants are always implicitly referenced.
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
        "primaryRef"    : ("property", "element", "id", "db", "dbAc", "refType", "refTypeAc"), # also secondary and version
        "secondaryRef"  : ("property", "element", "id", "db", "dbAc", "refType", "refTypeAc"),
        # names         : property, nametype, label, code, value
        "shortLabel"    : ("property", "element", None, None, "content"),
        "fullName"      : ("property", "element", None, None, "content"),
        "alias"         : ("property", "element", "type", "typeAc", "content"),
        # organisms     : taxid
        "hostOrganism"  : ("ncbiTaxId",)
        }

    scopes = {
        "entry"                 : "entry",
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

        # For transient identifiers.

        self.identifiers = {
            "entry"                 : 0,
            "interaction"           : 0,
            "interactor"            : 0,
            "participant"           : 0,
            "experimentDescription" : 0
            }

    def get_scope_and_context(self):

        """
        Get the scope of the current path as the entity to which the current
        attributes and content belong. Return this scope and its parent, or
        return (None, None) if no scope can be found.
        """

        scope = None

        # Go through the path from the deepest element name to the root, looking
        # for a scope name. Then, with a scope name, get the next element as the
        # more general context.

        for part in self.current_path[-1::-1]:

            # Define a scope if a suitable element is found.

            if scope is None and part in self.scopes.values():
                scope = part

            # Define the context if a scope has been found.

            elif scope is not None:
                return scope, part
        else:
            return scope, None

        return None, None

    def is_implicit(self, name, parent):

        """
        Return whether the element with the given 'name' defines an implicit
        (not externally referenced) element, given the 'parent' element name.
        """

        return name == "participant" or name == "interactor" and parent == "participant"

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
                parent = self.current_path[-1]

                # Handle PSI MI XML 1.0 identifiers which are absent.
                # Also assign identifiers to entries.

                # Use transient participant identifiers since these might be
                # reused within interactions (seen in InnateDB).

                # Also use transient interactor identifiers where their
                # relationship to participants is implicit, since these might be
                # reused within interactions (seen in InnateDB).

                if not attrs.has_key("id") or self.is_implicit(name, parent):
                    attrs = dict(attrs)
                    attrs["id"] = str(self.identifiers[name])
                    self.identifiers[name] += 1

        EmptyElementParser.startElement(self, name, attrs)

    def endElement(self, name):
        EmptyElementParser.endElement(self, self.scopes.get(name, name))

    def handleElement(self, content):

        "Handle a completed element with the given 'content'."

        if "entry" not in self.current_path:
            return

        element, parent, property, section = map(lambda x, y: x or y, self.current_path[-1:-5:-1], [None] * 4)
        attrs = dict(self.current_attrs[-1])
        entry = self.path_to_attrs["entry"]["id"]

        # Get mappings from experiments to interactions.
        # The "ref" attribute is from PSI MI XML 1.0.

        if element == "experimentRef":
            if parent == "experimentList":
                self.writer.append((element, entry, content or attrs["ref"], self.path_to_attrs["interaction"]["id"]))

        # And mappings from interactors to participants to interactions.
        # The "ref" attribute is from PSI MI XML 1.0.

        elif element == "interactorRef":
            if parent == "participant":
                self.writer.append((element, entry, content or attrs["ref"], "explicit", self.path_to_attrs["participant"]["id"], self.path_to_attrs["interaction"]["id"]))

        # Implicit interactor-to-participant mappings (applying only within participant elements).

        elif element == "interactor":
            if parent == "participant":
                self.writer.append((element, entry, attrs["id"], "implicit", self.path_to_attrs["participant"]["id"], self.path_to_attrs["interaction"]["id"]))

        # Implicit mappings applying only within an interaction scope.

        elif element == "experimentDescription":
            if self.path_to_attrs.has_key("interaction"):
                self.writer.append((element, entry, attrs["id"], self.path_to_attrs["interaction"]["id"]))

        # Interactor organisms.

        elif element == "organism":
            if parent == "interactor":
                implicit = self.is_implicit(parent, property) and "implicit" or "explicit"
                self.writer.append((element, entry, parent, self.path_to_attrs["interactor"]["id"], implicit, attrs["ncbiTaxId"]))

        # Get other data. This is of the form...
        # section/property/parent/element
        # For example:
        # interactorList/interactor/xref/primaryRef

        else:
            # Only consider supported elements.

            names = self.attribute_names.get(element)
            if not names:
                return

            # Exclude certain element occurrences (as also done above).
            # Such occurrences do not define entities and are therefore not of
            # interest.

            if property == "interactor" and section not in ("participant", "interactorList") or \
                property == "participant" and section != "participantList":
                return

            # Insist on a scope.

            scope, context = self.get_scope_and_context()
            if not scope or scope == "entry":
                return

            # Determine whether the information is provided as part of separate
            # (explicit) or embedded (implicit) definitions.

            implicit = self.is_implicit(scope, context) and "implicit" or "explicit"

            # Gather together attributes.

            if content:
                attrs["content"] = content

            # Get the property and element.

            attrs["property"] = property
            attrs["element"] = element

            # Copy the required attributes.

            values = []
            for key in names:
                values.append(attrs.get(key))

            # Only write data for supported elements providing data.

            if not values:
                return

            # The parent indicates the data type as is only used to select the output file.

            self.writer.append((parent, entry, scope, self.path_to_attrs[scope]["id"], implicit) + tuple(values))

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
        i = 1
        data_directory = sys.argv[i]
        source = sys.argv[i+1]
        filenames = sys.argv[i+2:]
    except IndexError:
        print >>sys.stderr, "Usage: %s <data directory> <data source name> <data file>..." % progname
        sys.exit(1)

    writer = Writer(data_directory, source)
    writer.reset()

    parser = PSIParser(writer)
    try:
        for filename in filenames:
            parser.parse(filename)
    finally:
        writer.close()

# vim: tabstop=4 expandtab shiftwidth=4
