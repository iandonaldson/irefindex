#!/usr/bin/env python

"""
Handling of data outside the database and for preparation for import into the
database.
"""

import codecs

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

# vim: tabstop=4 expandtab shiftwidth=4
