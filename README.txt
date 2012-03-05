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
retrieved in a particular order.

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
