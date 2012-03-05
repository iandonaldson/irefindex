#!/usr/bin/env python

"Convert tab-separated files (such as report logs) into a Wiki page."

from os.path import join

def file_to_wiki(filename, wikitype, separator, blank_value, use_headings, out):
    f = open(filename)
    try:
        if wikitype == "MediaWiki":
            out.write('{| cellspacing="0" cellpadding="5"\n')

        first_line = 1
        for line in f.xreadlines():

            if wikitype == "MediaWiki" and not first_line:
                out.write("|-\n")

            extra_before = ""
            extra_after = ""

            if use_headings and first_line:
                if wikitype == "MediaWiki":
                    extra_before = """align="center" style="background:#f0f0f0;"|'''"""
                    extra_after = """'''"""
                elif wikitype == "MoinMoin":
                    extra_before = """<style="text-align: center; background:#f0f0f0;"> '''"""
                    extra_after = """'''"""

            first_column = 1
            for column in line.rstrip().split(separator):
                if wikitype == "MediaWiki" and first_column:
                    out.write("| ")
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
            if wikitype == "MoinMoin":
                out.write("||\n")

            first_line = 0

        if wikitype == "MediaWiki":
            out.write("|}\n")

    finally:
        f.close()

def files_to_wiki(file_descriptions, data_directory, category, wikitype, out):
    for title, filename, separator, blank_value, use_headings in file_descriptions:
        out.write("== %s ==\n" % title)
        out.write("\n")
        file_to_wiki(join(data_directory, filename), wikitype, separator, blank_value, use_headings, out)
        out.write("\n")

    if wikitype == "MediaWiki":
        out.write("[[Category:%s]]\n" % category)
    elif wikitype == "MoinMoin":
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
        ("Interactions available from major taxonomies",                "rigids_by_originaltaxid_top",          "\t",   "",     True),
        ("Interactions available from major taxonomies (corrected)",    "rigids_by_taxid_top",                  "\t",   "",     True),
        ("Interactions",                                                "rigids_shared_as_grid",                ",",    "-",    False),
        ("Interactors",                                                 "rogids_shared_as_grid",                ",",    "-",    False),
        ("Summary of mapping interaction records to RIGs (Table 5)",    "interaction_coverage_by_source",       "\t",   "",     True),
        ("Assignment of protein interactors to ROGs (Table 3)",         "rogid_coverage_by_source",             "\t",   "",     True),
        ("ROG summary",                                                 "rogids_by_score_and_source_as_grid",   ",",    "-",    True),
        ]

    try:
        files_to_wiki(file_descriptions, data_directory, "iRefIndex", format, out)
    finally:
        if filename != "-":
            out.close()

# vim: tabstop=4 expandtab shiftwidth=4
