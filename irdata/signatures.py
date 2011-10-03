#!/usr/bin/env python

import base64, re

try:
    from hashlib import sha1
except ImportError:
    import sha
    def sha1(s):
        return sha.new(s)

strip_regexp = re.compile("[^A-Z0-9]")

def fix_signatures(signatures):

    "Remove prefixes from the given 'signatures'."

    fixed = []
    for signature in signatures:
        if not signature:
            return None
        parts = signature.split(":")
        if len(parts) > 1:
            signature = parts[1]
        fixed.append(signature)
    return fixed

def combine_signatures(signatures, legacy=0):

    """
    Combine the given 'signatures', sorting and digesting them. If the optional
    'legacy' parameter is set to a true value, the signatures will be converted
    to upper case and have non-alphanumeric characters removed.
    """

    signatures.sort()
    return make_signature("".join(signatures), legacy)

def make_signature(sequence, legacy=0):

    """
    Make a signature from the given 'sequence' (which may actually be a
    combination of signatures as opposed to a protein sequence). If the optional
    'legacy' parameter is set to a true value, the signatures will be converted
    to upper case and have non-alphanumeric characters removed.
    """

    if legacy:
        sequence = strip_regexp.sub("", sequence.upper())
    return base64.b64encode(sha1(sequence).digest())[:-1]

def process_file(f, out, combine=None, digest=None, legacy=0):

    """
    Process the file accessed via the object 'f', writing output to the 'out'
    stream, combining signatures if the optional 'combine' parameter is set to a
    sequence of column indexes indicating the columns providing data to be
    combined, or making a signature if the optional 'digest' parameter is set to
    a column index indicating the column providing data to be digested.

    Sequences or signatures will be converted to upper case, stripping
    non-alphanumeric characters, if the optional 'legacy' parameter is set to a
    true value. This is not recommended.
    """

    for line in f.xreadlines():
        columns = line.rstrip("\n").split("\t")

        # Either combine existing signatures, making a new one...

        if combine is not None:
            signatures = fix_signatures([columns[i] for i in combine])
            if signatures:
                columns.append("rigid:" + combine_signatures(signatures, legacy))
            else:
                columns.append("")

        # Or make a signature from the last column...

        elif digest is not None:
            columns[-1] = make_signature(columns[digest], legacy)

        else:
            raise ValueError, "Columns should be combined or a single column should be digested."

        out.write("\t".join(columns) + "\n")

# vim: tabstop=4 expandtab shiftwidth=4
