#!/usr/bin/env python

"Setup file for irdata."

from distutils.core import setup
from glob import glob
from os.path import join

setup(
    name="irdata",
    version="0.1",
    author="Paul Boddie",
    author_email="paul.boddie@biotek.uio.no",
    url="http://irefindex.org/",
    description="The iRefIndex data processing distribution",
    packages=[
        "irdata",
        # Add new modules here.
        ],
    # Install a modified irdata-config file from the current directory, if present.
    scripts = glob(join("scripts", "*")) + \
              glob(join("tools", "*.py")) + \
              glob(join("tools", "*.sh")) + \
              glob("irdata-config"),
    data_files = [
        (join("share", "irdata", "sql"), glob(join("sql", "*.sql")) + glob(join("sql", "*.txt"))),
        (join("share", "irdata", "sql", "mysql"), glob(join("sql", "mysql", "*.sql"))),
        (join("share", "irdata", "reports"), glob(join("reports", "*.sql"))),
        (join("share", "irdata", "manifests"), glob(join("manifests", "*.txt"))),
        (join("share", "irdata", "resources"), glob(join("resources", "*.irct")) + glob(join("resources", "*.txt"))),
        ]
    )

# vim: tabstop=4 expandtab shiftwidth=4
