The irdata distribution is a collection of software for building iRefIndex
database releases.

Prerequisites
-------------

The following software is required to use this distribution:

  * PostgreSQL (to host the database)
  * The PostgreSQL client program, psql, and database management tools
    (initdb, createdb)
  * A POSIX-like shell and environment (for the high-level scripts)
  * Python (tested with 2.5.4, for the tools)
  * cmdsyntax (command option processing)
  * libxml2dom (HTML parsing for the manifest generation)
  * libxml2 (required by libxml2dom)

Most Unix-based operating systems will provide the necessary commands for the
high-level scripts, but these commands may be provided separately or
explicitly on some platforms by packages such as GNU Coreutils and Findutils.
Amongst the commands used are the following:

  cat, cp, grep, gunzip, head, mv, rm, sort, tail, tee, xargs

In addition, where a previous release resides in a database system such as
MySQL, the MySQL client program, mysql, must be installed.

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
scripts directory into this software's distribution directory (normally
containing this file) and modified:

  cp scripts/irdata-config .

The SYSPREFIX setting should then be changed to state the directory at the top
of the desired hierarchy. The setup.py script can then be run:

  python setup.py install --prefix=/home/irefindex/usr

Note that SYSPREFIX will be /home/irefindex in this case: the setup.py script
needs the additional "/usr" to know where to install programs and resources.

Even if a system-wide installation ends up with inappropriate settings, such
settings can be overridden as described in "Configuring the Software".

Reserving a Location for Data
-----------------------------

Before any operations can be performed using the software installation,
various data and resource locations must be initialised. This can be done as
follows:

  irdata-config --make-system-dirs

If the software is being run from the distribution directory, the following
command must be run:

  mkdir data

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

Once the database system has been started, the database used by this software
can be initialised using the following command:

  irinit --init

Downloading Source Data
-----------------------

Source data is downloaded using the following command:

  irdownload --all

Any sources that could not be downloaded in their entirety will be reported as
having failed. It is then necessary to attempt to download them individually
and potentially investigate any underlying problems with each of the download
activities.

Generating Manifest Information
-------------------------------

Manifest/release information for the data sources is generated using the
following command:

  irmanifest --all

Any sources that could not provide manifests will be reported as having
failed. Re-running irmanifest with specific source names will add information
for those sources to the manifest file, although some investigation of
problems related to manifest/release information retrieval may be necessary.

Unpacking Source Data
---------------------

The downloaded data is typically provided in the form of compressed archives
potentially containing many individual files. Before parsing can be performed,
such archives must be unpacked, and this can be done for all sources as
follows:

  irunpack --all

Parsing Source Data
-------------------

The source data must be parsed and converted to a form that can be imported
into the database. Before attempting to parse data, the presence of the
required data files should be established:

  irparse --no-parse --all

It is also possible to check XML data using the xmllint tool using a command
of the following form:

  irparse --check <source>

However, xmllint may require excessive amounts of memory for some files and is
not generally suitable for the task.

Parsing of the source data is done as follows:

  irparse --all

Once parsed, the import data will reside in an "import" subdirectory of the
main data directory. Thus, if the main data directory is /home/irefindex/data
then the import data will reside in /home/irefindex/data/import. Parsing
errors will be reported on standard error.

Importing Source Data
---------------------

Source data is imported into the database using the following command:

  irimport --all

Obtaining Integer Identifiers from Previous Releases
----------------------------------------------------

Although iRefIndex employs unique identifiers in the form of RIG and ROG
identifiers, it also maintains sequential numbering for interactions and
interactors in order to more easily support applications whose notion of
identifiers are limited to integers. Since correspondences between identifier
types will have been defined by previous iRefIndex releases, such resources
should be extracted from their release databases and then imported into the
current release database in order to refer to known entities in a fashion
consistent with previous releases.

Integer identifiers are obtained from a previous release using the following
command:

  irprevious --pgsql <database>

In the above form, with <database> substituted with an actual database name,
the identifiers will be exported from a PostgreSQL database system.

For MySQL-based releases of iRefIndex, the following command is required:

  irprevious --mysql -h <host> -u <username> -p -A -D <database>

In this form, each of the placeholders must be substituted with the relevant
values. In addition, other options may be employed after the --mysql argument
in addition to or in place of those shown in order to connect to the database
system.

Finishing the Build
-------------------

Once the source data resides in the database, it is processed by a sequence of
operations that can be invoked as follows:

  irbuild --build

If reports are to be generated, this can be done by specifying the --reports
option when building or by running the command with only that option
specified:

  irbuild --reports

The report output includes a summary Wiki page featuring a selection of
individual reports which can be published when the build has been completed.

Output files are generated using the following command:

  irbuild --output

The primary output format is PSI-MI TAB, also known as MITAB.

Notes on Source Formats
-----------------------

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

MPIDB sources employ a MITAB variant which exposes experimental details in a
non-standard way. This can result in interactions being assigned multiple
interaction types, which is typically not done by XML-based sources even
though the schema does permit it.
