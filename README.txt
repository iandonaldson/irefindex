Notes on Formats
----------------

MIPS and OPHID use version 1.0 of the specification and needs to provide values
using different elements.

OPHID provides multiple entry elements in the same file, thus making things like
experiment references local to a particular entry.

OPHID refers to the same experiment more than once in some interactions.

DIP uses participant identifiers which are local to each interaction.

InnateDB reuses participant identifiers even within the same interaction, and
also reuses interactor identifiers within the same interaction, even when the
interactors are different! Moreover, InnateDB maintains a separate interactor
list but does not reference those interactors.
