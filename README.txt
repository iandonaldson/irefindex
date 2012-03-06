The irdata distribution is a collection of software for building iRefIndex
database releases.

Prerequisites
-------------

The following software is required to use this distribution:

  * A POSIX-like shell and environment (for the high-level scripts)
  * Python (tested with 2.5.4, for the tools)
  * cmdsyntax (command option processing)

Most Unix-based operating systems will provide the necessary commands for the
high-level scripts, but these commands may be provided separately or
explicitly on some platforms by packages such as GNU Coreutils and Findutils.
Amongst the commands used are the following:

  cat, cp, grep, gunzip, head, mv, rm, sort, tail, tee, xargs

Configuring the Software
------------------------

A configuration script called irdata-config is located in the scripts
directory of this distribution. It may be edited or copied to another location
on the PATH of any user running the software.

Using the Software
------------------

Once the prerequisites have been installed, the software can be run from the
distribution directory. Alternatively, a system-wide installation can be
performed or prepared using the setup.py script provided. Such an installation
can then be used by making sure that the PATH can find the installed programs.

Configuring an Installation of the Software
-------------------------------------------

If a system-wide installation is to reside in a directory hierarchy other than
the conventional system root (that being /, with programs situated in
/usr/bin, and so on), the configuration script should be copied from the
scripts directory into the same directory as this file and modified:

  cp scripts/irdata-config .

The SYSPREFIX setting should then be changed to state the directory at the top
of the desired hierarchy. The setup.py script can then be run:

  python setup.py install --prefix=/home/irefindex/usr

Note that SYSPREFIX will be /home/irefindex in this case: the setup.py script
needs the additional "/usr" to know where to install programs and resources.

Even if a system-wide installation ends up with inappropriate settings, such
settings can be overridden as described in "Configuring the Software".

Creating the Database
---------------------

Due to limitations with PostgreSQL and the interaction between locales and the
sorting/ordering of textual data, it is essential that the database be
initialised in a "cluster" with a locale that employs the ordering defined for
ASCII character values. Such a cluster can be defined as follows:

  initdb -D /home/irefindex/data --no-locale

A database can be created using the usual PostgreSQL tools:

  createdb irdata

If the use of a separate cluster is undesirable, PostgreSQL 9.1 or later could
be used by employing various explicit "collate" declarations in certain column
declarations or in various SQL statements where ROG identifiers are being
retrieved in a particular order. This is not currently supported.

Initialising the Database
-------------------------



Notes on Formats
----------------

Generally, identifier locality restrictions are not prominently specified or
adhered to.

  * For version 1.0, the xs:ID type is used for id attributes, but sources
    like OPHID repeat values of such attributes.

  * For version 2.5, the xs:int type is used for id attributes, and it is
    noted that these refer to distinct entities throughout a file. However,
    participant identifiers are effectively local and may not have any meaning
    at all.

MIPS and OPHID use version 1.0 of the specification and need to provide values
using different elements, although these elements correspond directly to
elements in version 2.5.

OPHID provides multiple entry elements in the same file, thus making things like
experiment references local to a particular entry.

OPHID refers to the same experiment more than once in some interactions.

DIP and other sources use participant identifiers which are local to each
interaction.

InnateDB reuses participant identifiers even within the same interaction, and
also reuses interactor identifiers within the same interaction, even when the
interactors are different! Moreover, InnateDB maintains a separate interactor
list but does not reference those interactors.

HPRD occasionally misuses reference attributes such as in the following
example (from data/HPRD/PSIMI_XML/08855_psimi.xml):

<secondaryRef db="uniprot" dbAc="MI:0486" id="Q0VAR9,Q96CW7"/>
