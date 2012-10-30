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
  * The jar utility (required to package iRefScape data)

Most Unix-based operating systems will provide the necessary commands for the
high-level scripts, but these commands may be provided separately or
explicitly on some platforms by packages such as GNU Coreutils and Findutils.
Amongst the commands used are the following:

  cat, cp, grep, gunzip, head, mv, rm, sort, tail, tee, xargs

In addition, where a previous release resides in a database system such as
MySQL, the MySQL client program, mysql, must be installed.

See the "Resources" section for download information.

Technical Documentation
-----------------------

The documentation is in a format that can be used with MoinMoin (and the
ImprovedTableParser extension) for deployment on the Web.

See docs/pages/Project for details of how this distribution is arranged and
constructed.

See docs/pages/Schema for information about the database schema.

See docs/pages/Sources for details of data source formats and issues.

Configuring the Software
------------------------

A configuration script called irdata-config is located in the scripts
directory of this distribution. It may be edited or copied to another location
on the PATH of any user running the software.

Before continuing, enter the distribution directory (normally containing this
README.txt file) and copy the irdata-config file into the current directory as
follows:

  cp scripts/irdata-config .

The details in the file can now be reviewed and edited. If an installation is
performed, any edits after installation can be incorporated into that
installation by once again running the command given in "Performing an
Installation" in the distribution directory.

Reserving a Location for Data
-----------------------------

The configuration script contains a setting dedicated to the data downloaded
and processed by the software. By default, it looks like this:

  DATA=                                       # user defined data directory location

Left in this state, the system will attempt to locate the data relative to the
installed software. However, it can be beneficial to explicitly choose a
location, especially if the data will reside in a separate partition from the
installed software. For example:

  DATA=/mnt/storage/data

Note that this DATA setting is not connected with the database system that
will also used to store and process data during the build process. See below
for database system configuration information.

Configuring an Installation of the Software
-------------------------------------------

Once the prerequisites have been installed, the software can be run from the
distribution directory. If you choose to do this, you can skip this and the
following installation sections. Make sure, in this case, to leave SYSPREFIX
blank in the irdata-config file:

  SYSPREFIX=                                  # system-wide installation root

Alternatively, a system-wide installation can be performed or prepared using
the setup.py script provided. You can choose the conventional system root as
follows, although this is not recommended:

  SYSPREFIX=/                                 # system-wide installation root

The reason for not recommending this is that programs would be installed in
/usr/bin, and other resources in other locations that should normally be
managed by the system's package manager. If you would prefer to install the
software centrally in this way, please consider using a packaged version of
this software.

If a system-wide installation is to reside in a directory hierarchy other than
the conventional system root, the SYSPREFIX setting should be adjusted to
reflect this. For example:

  SYSPREFIX=/home/irefindex                   # system-wide installation root

This setting specifies the directory at the top of the desired hierarchy. Upon
installing the software, given this example, programs would be placed in
/home/irefindex/usr/bin.

Even if a system-wide installation ends up with inappropriate settings, such
settings can be overridden as described in "Configuring the Software".

Performing an Installation
--------------------------

With the irdata-config file modified, the setup.py script can then be run:

  python setup.py install --prefix=/home/irefindex/usr

Note that SYSPREFIX will be /home/irefindex in this case: the setup.py script
needs the additional "/usr" to know where to install programs and resources.

Setting PATH and PYTHONPATH
---------------------------

With a SYSPREFIX other than / (the conventional system root), such as
/home/irefindex, the PATH and PYTHONPATH variables in the environment need to
be modified so that the shell can find the installed programs and libraries.

To obtain suggested definitions of these variables, run the following command
in the distribution directory of this software:

  scripts/irdata-show-settings --suggested

The output should provide output resembling the following for a SYSPREFIX of
/home/irefindex:

  export PATH=/home/irefindex/usr/bin:$PATH
  export PYTHONPATH=/home/irefindex/usr/lib/python2.6/site-packages:$PYTHONPATH

These definitions can be executed in the shell, and they can also saved in the
appropriate shell configuration file, such as in .profile, .bashrc,
.bash_profile or any other appropriate file in a user's home directory.

Initialising a Location for Data
--------------------------------

Before any operations can be performed using the software installation,
various data and resource locations must be initialised. This can be done as
follows:

  irdata-show-settings --make-dirs

Any required directories that are not already present will be reported as
being created.

Creating a Database Cluster
---------------------------

On systems that already provide databases, it may not be necessary to create a
database cluster. Nevertheless, it can be worth checking to see if any
existing database cluster is appropriately configured, and this is described
below.

Due to limitations with PostgreSQL and the interaction between locales and the
sorting/ordering of textual data, it is essential that the database be
initialised in a "cluster" with a locale that employs the ordering defined for
ASCII character values. Such a cluster can be defined as follows:

  initdb -D /home/irefindex/pgdata --no-locale

On Debian-based systems (including Ubuntu and derivatives), a cluster can be
defined using a special command, in the following example specifying a
PostgreSQL version of 8.2 and a cluster name of irdata:

  pg_createcluster --locale=C 8.2 irdata

Note that the cluster's data directory is different from the data directory
employed by this software to collect source data and to deposit processed
data.

Note also that the default location of clusters is typically in the
/var/lib/postgresql region of the filesystem, at least for Debian packages of
PostgreSQL, which can lead to disk space issues since /var is often given a
partition of limited size or resides within the root partition which may
itself have a limited size.

To choose an alternative location for a cluster, add the -d option:

  pg_createcluster --locale=C -d /home/irefindex/databases 8.2 irdata

A cluster can be started as follows:

  pg_ctl -D /home/irefindex/pgdata start

On Debian-based systems, the following command is used instead:

  pg_ctlcluster 8.2 irdata start

To list the available clusters on Debian-based systems:

  pg_listclusters

This should show, amongst other things, the location, status, locale and port
number associated with each of the available clusters.

Connecting to Databases and Clusters
------------------------------------

See the documentation for PostgreSQL and the various tools (createdb, psql)
for details of connecting to a specific cluster. Generally, the -p option is
used to direct an operation towards a particular cluster. For example, for a
cluster listening on port 5433, the following command lists the available
databases:

  psql -p 5433 -l

Any connection options must be given in the configuration of this software
using the PSQL_OPTIONS setting. For example, for a cluster listening on port
5433 the following could be used in the configuration file:

  PSQL_OPTIONS="--psql-options -p 5433"

If the use of a separate cluster is undesirable, PostgreSQL 9.1 or later could
be used by employing various explicit "collate" declarations in certain column
declarations or in various SQL statements where ROG identifiers are being
retrieved in a particular order. This is not currently supported.

Creating a Database User
------------------------

It is recommended that iRefIndex be run using a separate database user or
role, and this user can be set up as follows:

  createuser irefindex

(Additional connection options should be specified to affect the appropriate
database cluster.)

Although making the new user a superuser may appear excessive, doing so will
allow the user to create databases, tables and other objects without any
further configuration.

The choice of username can also be important. PostgreSQL is able to associate
system users with database users, and so any database user should have the
same name as the system user running the iRefIndex software in order to take
advantage of this feature. If the way databases are managed in your own
environment diverges from this practice, you may choose another username
instead, but this will then need to be specified in the connection options
described above.

Creating the Database
---------------------

Once a database cluster has been started, a database can then be created using
the usual PostgreSQL tools:

  createdb irdata

(Additional connection options should be specified to affect the appropriate
database cluster.)

Configuring the Database
------------------------

PostgreSQL configuration can be challenging. An example configuration can be
found in the docs directory in the form of the postgresql.conf file. Although
the settings have been known to change from one release of PostgreSQL to the
next, the following appear to be crucial:

  max_connections           (10)
  shared_buffers            (25% of RAM where 1GB or more is available)
  work_mem                  (64MB)
  maintenance_work_mem      (1GB)
  wal_buffers               (8MB)
  checkpoint_segments       (128)
  effective_cache_size      (50% of RAM)
  default_statistics_target (500)

For non-interactive systems, the autovacuum feature can be switched off. This
helps to avoid contention due to table locking performed by the autovacuum
daemon.

More information can be found in the PostgreSQL documentation:

  http://www.postgresql.org/docs/9.1/interactive/runtime-config-resource.html
  http://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server

Initialising the Database
-------------------------

Once the database system has been started, the database used by this software
can be initialised using the following command:

  irinit --init

Should the need arise for the removal of schema information from the database,
the following command can be used:

  irdrop --drop --all

However, it may be more convenient to issue the dropdb command on the database
and recreate it as described above.

To drop only the build products and not imported source data, run the
following:

  irdrop --drop --build

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

Additional options are available to uncompress all downloaded files, which can
be useful for inspecting the data, but the parsing process should be able to
handle compressed single files in gzip format and thus avoid expanding such
files in the filesystem.

Parsing Source Data
-------------------

The source data must be parsed and converted to a form that can be imported
into the database. Before attempting to parse data, the presence of the
required data files should be established:

  irparse --no-parse --all

It is also recommended that XML data is checked for correctness using a
command of the following form:

  irparse --check --all

See the section below on handling invalid source data if this command produces
errors.

Parsing of the source data is done as follows:

  irparse --all

Once parsed, the import data will reside in an "import" subdirectory of the
main data directory. Thus, if the main data directory is /home/irefindex/data
then the import data will reside in /home/irefindex/data/import. Parsing
errors will be reported on standard error.

Handling Invalid Source Data
----------------------------

Currently, the only serious case of invalid data is the lack of proper
encoding information in BIND Translation data files, causing errors resembling
the following:

irparse-source: Examining BIND_TRANSLATION...
irparse-source: File /home/irefindex/var/lib/irdata/data/BIND_Translation/taxid10090_PSIMI25.xml in source BIND_TRANSLATION failed.
irparse-source: File /home/irefindex/var/lib/irdata/data/BIND_Translation/taxid9606_PSIMI25.xml in source BIND_TRANSLATION failed.
irparse-source: Source BIND_TRANSLATION had invalid data.

These files can be fixed by adding a proper XML declaration with encoding
details as follows:

  irparse --fix BIND_TRANSLATION

Although the --fix option can be used for all data sources, this is not
generally recommended because the nature of errors may vary and need proper
investigation.

Fixed sources can be parsed individually once fixed. For example:

  irparse BIND_TRANSLATION

Importing Source Data
---------------------

Source data is imported into the database using the following command:

  irimport --all

Each imported source should have its name emitted on standard output. Errors
are produced on standard error.

To perform a cursory check for the presence of data for all sources, run the
following command:

  irimport --check --all

A list of imported sources will be produced on standard output. Any missing
sources will be reported in messages written to standard error.

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

Uploading the Output Files
--------------------------

Traditionally, iRefIndex releases have been published in a directory structure
having a particular form. Given a particular root directory for an area of the
filesystem exposed via FTP or HTTP (or another mechanism) for the purpose of
downloading the release data, such as...

  /home/ftp/irefindex

...the following command can be used to copy the MITAB release data into such
a directory structure:

  irupload --upload /home/ftp/irefindex --mitab

The result of this command will be the construction of a hierarchy of
directories of the following form:

  data/archive/release_X.Y/psi_mitab/MITAB2.6

Thus, the following hierarchy will be created for the example root directory
given above and a release number of 10.0:

  /home/ftp/irefindex/data/archive/release_10.0/psi_mitab/MITAB2.6

Similarly, the iRefScape data can be published as follows:

  irupload --upload /home/ftp/irefindex --irefscape

The result of this command will be a different hierarchy:

  Cytoscape/plugin/archive/release_X.Y

And, for the example root directory and release number, the following
hierarchy will be created:

  /home/ftp/irefindex/Cytoscape/plugin/archive/release_10.0

It has also been the accepted convention to provide a symbolic link to direct
users to the "current" release. This link can be set up in the published
directory hierarchy by using the following commands:

  irupload --update-current /home/ftp/irefindex --mitab
  irupload --update-current /home/ftp/irefindex --irefscape

Thus, the current release can be updated after the release data has been
published.

After issuing the above commands, symbolic links will be created in the
following locations:

  /home/ftp/irefindex/data/current
  /home/ftp/irefindex/Cytoscape/plugin/current

Contact, Copyright and Licence Information
------------------------------------------

The current Web page for this software at the time of release is:

http://irefindex.uio.no/wiki/irdata

The current maintainer can be contacted at the following e-mail address:

paul.boddie@biotek.uio.no

Copyright and licence information can be found in the docs directory - see
docs/COPYING.txt and docs/gpl-3.0.txt for more information.

Resources
---------

The following locations provide the prerequisites for this system:

  PostgreSQL    http://www.postgresql.org/
  Python        http://www.python.org/
  cmdsyntax     http://www.boddie.org.uk/david/Projects/Python/CMDSyntax/
  libxml2dom    http://www.boddie.org.uk/python/libxml2dom.html
  libxml2       http://www.xmlsoft.org/
  jar           http://www.oracle.com/technetwork/java/javase/downloads/index.html
                (jar should be provided by the JDK)

The intention is that operating system packages should provide such
prerequisites, but there remains a possibility that not all prerequisites will
be packaged for all operating system distributions.
