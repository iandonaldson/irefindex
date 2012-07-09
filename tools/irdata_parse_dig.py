#!/usr/bin/env python

"""
Parse DIG format text files, writing disease group details to standard output.

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

import re

disease_omim = re.compile(r"(\d{6})")
disease_tag = re.compile(r"\((\d)\)(?:\s+\(\?\))?$")

if __name__ == "__main__":
    from irdata.cmd import get_progname
    from irdata.data import RawImportFile, bulkstr
    import sys

    progname = get_progname()

    try:
        i = 1
        filename = sys.argv[i]
    except IndexError:
        print >>sys.stderr, "Usage: %s <data file>" % progname
        sys.exit(1)

    f = open(filename)
    writer = RawImportFile(sys.stdout)

    try:
        for _digid, line in enumerate(f.xreadlines()):
            title, genes, gene_omimid, locus = [column.strip() for column in line.strip().split("|")]
            name_end = len(title)

            # Get the OMIM identifer if present.

            match = disease_omim.search(title)
            if match:
                disease_omimid = match.group(1)
                name_end = match.span()[0]
            else:
                disease_omimid = None

            # Get the tag if present.

            match = disease_tag.search(title)
            if match:
                tag = match.group(1)
                name_end = min(name_end, match.span()[0])
            else:
                tag = None

            # Get the actual disease name by excluding the above details.

            name = title[:name_end].strip(", ")

            genes = "|".join([geneid.strip() for geneid in genes.split(",")])
            writer.append(map(bulkstr, [_digid + 1, title, name, disease_omimid, tag, genes, gene_omimid, locus]))

    finally:
        writer.close()
        f.close()

# vim: tabstop=4 expandtab shiftwidth=4
