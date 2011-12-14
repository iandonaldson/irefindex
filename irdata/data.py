#!/usr/bin/env python

"""
Handling of data outside the database and for preparation for import into the
database.
"""

import codecs, os

def rewrite(stream, encoding="utf-8"):

    "Re-open the given 'stream' for writing, applying the specified 'encoding'."

    writer = codecs.getwriter(encoding)
    return writer(stream)

# Basic value handling.

def bulkstr(x):

    "Perform PostgreSQL import file encoding on the string value 'x'."

    if x is None:
        return r"\N"
    else:
        x = unicode(x)
        if "\\" in x:
            return x.replace("\\", r"\\") # replace single backslash with double backslash
        else:
            return x

def tab_to_space(x):
    if x is None:
        return None
    else:
        return x.replace("\t", " ")

# Utility classes.

class Writer:

    "A simple writer of tabular data."

    def __init__(self, directory):
        self.directory = directory
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

    def close(self):
        for f in self.files.values():
            f.close()
        self.files = {}

# vim: tabstop=4 expandtab shiftwidth=4
