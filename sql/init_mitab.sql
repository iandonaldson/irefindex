-- A MITAB schema where the basic units of addressable information are as
-- follows:

-- Interactions: filename, interaction
-- Interactors:  filename, interaction, position
-- Experiments:  filename, line

begin;

-- Utilities

create aggregate array_accum (
    sfunc = array_append,
    basetype = anyelement,
    stype = anyarray,
    initcond = '{}'
);

-- Interactors (columns 1 and 2, plus 10 and 11)

create table mitab_uid (
    filename varchar not null,
    interaction varchar not null,
    position integer not null,
    dbname varchar not null,
    acc varchar not null,
    taxid integer not null,
    primary key(filename, interaction, position)
);

-- Alternatives (columns 3 and 4)

create table mitab_alternatives (
    filename varchar not null,
    interaction varchar not null,
    position integer not null,
    dbname varchar not null,
    alt varchar not null,
    primary key(filename, interaction, position, dbname, alt)
);

-- Aliases (columns 5 and 6)
-- The entry column replaces dbname, alias in the key.

create table mitab_aliases (
    filename varchar not null,
    interaction varchar not null,
    position integer not null,
    dbname varchar not null,
    alias varchar not null,
    entry varchar not null, -- counter
    primary key(filename, interaction, position, entry)
);

-- Method names (column 7)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_method_names (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    code varchar not null,
    name varchar not null,
    entry varchar not null,
    primary key(filename, line, entry)
);

-- Authors (column 8)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_authors (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    author varchar not null,
    entry varchar not null,
    primary key(filename, line, entry)
);

-- PubMed references (column 9)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_pubmed (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    pmid integer not null,
    entry varchar not null,
    primary key(filename, line, entry)
);

-- Interaction type names (column 12)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_interaction_type_names (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    code varchar not null,
    name varchar not null,
    entry varchar not null,
    primary key(filename, line, entry)
);

-- Sources (column 13)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_sources (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    sourcedb varchar not null,
    name varchar not null,
    entry varchar not null,
    primary key(filename, line, entry)
);

-- Source interactions (column 14)
-- Experiment-related information (in MPIDB).
-- The entry column provides a counter related to the interaction.

create table mitab_interaction_identifiers (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    dbname varchar not null,
    "uid" varchar not null,
    entry varchar not null,
    primary key(filename, interaction, line, entry)
);

-- Confidence scores (column 15)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_confidence (
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    "type" varchar not null,
    confidence integer not null,
    entry varchar not null,
    primary key(filename, line, entry)
);

commit;
