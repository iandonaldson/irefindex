#!/usr/bin/env python

"Setup file for irdata."

from distutils.core import setup
import glob, os

setup(
    name="irdata",
    version="0.1",
    author="Paul Boddie",
    author_email="paul.boddie@biotek.uio.no",
    url="http://irefindex.uio.no/",
    description="The iRefIndex data processing distribution",
    packages=[
        "irdata",
        # Add new modules here.
        ],
    # Install a modified irdata-config file in the current directory, if present.
    scripts = glob.glob(os.path.join("scripts", "*")) + \
              glob.glob(os.path.join("tools", "*.py")) + \
              glob.glob(os.path.join("tools", "*.sh")) + \
              glob.glob("irdata-config"),
    data_files = [
        (os.path.join("share", "irdata", "sql"), glob.glob(os.path.join("sql", "*.sql"))),
        (os.path.join("share", "irdata", "reports"), glob.glob(os.path.join("reports", "*.sql"))),
        ]
    )

# vim: tabstop=4 expandtab shiftwidth=4
