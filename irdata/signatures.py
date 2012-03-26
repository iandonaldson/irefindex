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

def process_file(f, out, column, separator=",", append=0, append_length=0, legacy=0):

    """

    Process the file accessed via the object 'f', writing output to the 'out'
    stream combining signatures or sequence data from the given 'column' where
    each signature or data item is delimited by the given 'separator'.

    If 'append' is set to a true value, the resulting signatures will be
    appended to the columns. Otherwise, the selected columns will be replaced by
    the results.

    If 'append_length' is set to a true value, the signature lengths will be
    appended to the columns.

    Sequences or signatures will be converted to upper case, stripping
    non-alphanumeric characters, if the optional 'legacy' parameter is set to a
    true value. This is not recommended.
    """

    for line in f.xreadlines():
        columns = line.rstrip("\n").split("\t")
        inputs = columns[column].split(separator)
        signatures = fix_signatures(inputs)

        if signatures:
            result = combine_signatures(signatures, legacy)
            if append:
                columns.append(result)
            else:
                columns[column] = result
            if append_length:
                columns.append(str(sum(map(len, signatures))))
        else:
            columns.append("")

        out.write("\t".join(columns) + "\n")

# vim: tabstop=4 expandtab shiftwidth=4
