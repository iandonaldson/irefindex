#!/usr/bin/env python

"""
XML parsing utilities.
"""

import xml.sax
import gzip
from os.path import splitext

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

        basename, ext = splitext(filename)

        if ext.endswith("gz"):
            opener = gzip.open
        else:
            opener = open

        f = opener(filename, "rb")
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

# vim: tabstop=4 expandtab shiftwidth=4
