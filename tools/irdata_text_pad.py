#!/usr/bin/env python

"""
Pad a text file to have a specific number of columns.
"""

from irdata.data import RawImportFileReader, RawImportFile, reread, rewrite
import irdata.cmd
import sys, cmdsyntax

syntax_description = """
    --help |
    -n <fields>
    -p <padding>
    [ <filename> | - ]
    """

# Main program.

def main():

    # Get the command line options.

    syntax = cmdsyntax.Syntax(syntax_description)
    try:
        matches = syntax.get_args(sys.argv[1:])
        args = matches[0]
    except IndexError:
        print >>sys.stderr, "Syntax:"
        print >>sys.stderr, syntax_description
        sys.exit(1)
    else:
        if args.has_key("help"):
            print >>sys.stderr, __doc__
            print >>sys.stderr, "Syntax:"
            print >>sys.stderr, syntax_description
            sys.exit(1)

    try:
        fields = int(args["fields"])
    except ValueError:
        print >>sys.stderr, "%s: Need a number of fields/columns." % irdata.cmd.get_progname()
        sys.exit(1)

    padding = args["padding"]

    if args.has_key("filename"):
        filename = filename_or_stream = args["filename"]
    else:
        filename_or_stream = reread(sys.stdin)
        filename = None

    reader = RawImportFileReader(filename_or_stream)
    writer = RawImportFile(rewrite(sys.stdout))

    try:
        try:
            for details in reader:

                # Pad the line to have at least as many fields as indicated.

                if len(details) < fields:
                    details += (fields - len(details)) * [padding]

                writer.append(details)

        except IOError, exc:
            print >>sys.stderr, "%s: %s" % (irdata.cmd.get_progname(), exc)

    finally:
        reader.close()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(1)

# vim: tabstop=4 expandtab shiftwidth=4
