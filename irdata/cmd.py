#!/usr/bin/env python

"Command line utilities."

import os, sys

def get_progname():
    return os.path.split(sys.argv[0])[-1]

def get_lists(arg):

    """
    Split 'arg' into lists of lists, with ':' separating the lists and ','
    separating elements in each list. The special element 'all', if found on its
    own in a list, will occur instead of an actual list in the result.
    """

    if not arg:
        return []

    lists = []
    for liststr in arg.split(":"):
        l = liststr.split(",")
        if l == ["all"]:
            l = "all"
        lists.append(l)
    return lists

# vim: tabstop=4 expandtab shiftwidth=4
