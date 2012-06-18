#!/usr/bin/env python

"""
Convert tab-separated files (such as report logs) into a Wiki page.

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

from os.path import join

def file_to_wiki(pathname, filename, wikitype, separator, blank_value, use_headings, column_types, out):
    f = open(pathname)
    try:
        if wikitype == "MediaWiki":
            out.write('{| cellspacing="0" cellpadding="5"\n')
        elif wikitype == "MoinMoinImproved":
            out.write("{{{#!table%s\n" % (
                use_headings and column_types and "%s%s%s" % (
                    (" name=%s" % filename),
                    use_headings and " headers=1" or "",
                    column_types and (" columntypes='%s'" % column_types) or ""
                    )
                    or ""
                ))

        first_line = 1
        for line in f.xreadlines():

            if not first_line:
                if wikitype == "MediaWiki":
                    out.write("|-\n")
                elif wikitype == "MoinMoinImproved":
                    out.write("==\n")

            extra_before = ""
            extra_after = ""

            if use_headings and first_line:
                if wikitype == "MediaWiki":
                    extra_before = """align="center" style="background:#f0f0f0;"|'''"""
                    extra_after = """'''"""
                elif wikitype.startswith("MoinMoin"):
                    extra_before = """<style="text-align: center; background:#f0f0f0;"> '''"""
                    extra_after = """'''"""

            first_column = 1
            for column in line.rstrip().split(separator):
                if first_column:
                    if wikitype == "MediaWiki":
                        out.write("| ")
                    elif wikitype == "MoinMoin":
                        out.write("||")
                else:
                    out.write("||")

                out.write(extra_before)
                if column != blank_value:
                    out.write(column)
                else:
                    out.write(" ")
                out.write(extra_after)

                first_column = 0

            if wikitype == "MediaWiki":
                out.write("\n")
            elif wikitype == "MoinMoin":
                out.write("||\n")
            elif wikitype == "MoinMoinImproved":
                out.write("\n")

            first_line = 0

        if wikitype == "MediaWiki":
            out.write("|}\n")
        elif wikitype == "MoinMoinImproved":
            out.write("}}}\n")

    finally:
        f.close()

def files_to_wiki(file_descriptions, data_directory, category, wikitype, out):
    for title, filename, separator, blank_value, use_headings, column_types in file_descriptions:
        out.write("== %s ==\n" % title)
        out.write("\n")
        file_to_wiki(join(data_directory, filename), filename, wikitype, separator, blank_value, use_headings, column_types, out)
        out.write("\n")

    if wikitype == "MediaWiki":
        out.write("[[Category:%s]]\n" % category)
    elif wikitype.startswith("MoinMoin"):
        out.write("----\n")
        out.write("Category%s\n" % category.capitalize()) # NOTE: Have to conform with MoinMoin category name restrictions.

if __name__ == "__main__":
    from irdata.cmd import get_progname
    from os.path import split
    import sys

    progname = get_progname()

    try:
        i = 1
        data_directory = sys.argv[i]
        filename = sys.argv[i+1]
        if len(sys.argv) > i+2:
            format = sys.argv[i+2]
        else:
            format = "MediaWiki"
    except IndexError:
        print >>sys.stderr, "Usage: %s <data directory> <output file> [ <format> ]" % progname
        sys.exit(1)

    leafname = split(filename)[-1]

    if filename != "-":
        out = open(filename, "w")
    else:
        out = sys.stdout

    file_descriptions = [
        # Title                                                         File                                    Separator   Blank   Headings    Column types
        ("Data source information",                                     "irefindex_manifest_final",             "\t",       "\\N",  True,       "0,1"),
        ("Interactions available from major taxonomies",                "rigids_by_originaltaxid_top",          "\t",       "",     True,       "0n,2nd"),
        ("Interactions available from major taxonomies (corrected)",    "rigids_by_taxid_top",                  "\t",       "",     True,       "0n,2nd"),
        ("Interactions",                                                "rigids_shared_as_grid",                ",",        "-",    False,      None),
        ("Interactors",                                                 "rogids_shared_as_grid",                ",",        "-",    False,      None),
        ("Summary of mapping interaction records to RIGs (Table 5)",    "interaction_coverage_by_source",       "\t",       "",     True,       "1nd,2nd,3nd,4nd,5nd,6nd"),
        ("Assignment of protein interactors to ROGs (Table 3)",         "rogid_coverage_by_source",             "\t",       "",     True,       "1nd,2nd,3nd,4nd,5nd,6nd,7nd,8nd"),
        ("ROG summary",                                                 "rogids_by_score_and_source_as_grid",   ",",        "-",    True,       None),
        ]

    try:
        files_to_wiki(file_descriptions, data_directory, "iRefIndex", format, out)
    finally:
        if filename != "-":
            out.close()

# vim: tabstop=4 expandtab shiftwidth=4
