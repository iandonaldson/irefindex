-- A MITAB schema where the basic units of addressable information are as
-- follows:

-- Interactions: source, filename, interaction
-- Interactors:  source, filename, interaction, position
-- Experiments:  source, filename, line (in parsed import data)

begin;

-- Interactors (columns 1 and 2, plus 10 and 11)

create table mitab_uid (
    source varchar not null,
    filename varchar not null,
    interaction varchar not null,
    position integer not null,
    dbname varchar not null,
    acc varchar not null,
    taxid integer not null,
    primary key(source, filename, interaction, position)
);

-- Alternatives (columns 3 and 4)

create table mitab_alternatives (
    source varchar not null,
    filename varchar not null,
    interaction varchar not null,
    position integer not null,
    dbname varchar not null,
    alt varchar not null,
    primary key(source, filename, interaction, position, dbname, alt)
);

-- Aliases (columns 5 and 6)
-- The entry column replaces dbname, alias in the key.
-- The entry column provides a counter related to the interactor.

create table mitab_aliases (
    source varchar not null,
    filename varchar not null,
    interaction varchar not null,
    position integer not null,
    dbname varchar not null,
    alias varchar not null,
    entry integer not null,
    primary key(source, filename, interaction, position, entry)
);

-- Method names (column 7)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_method_names (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    code varchar not null,
    name varchar not null,
    entry integer not null,
    primary key(source, filename, line, entry)
);

-- Authors (column 8)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_authors (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    author varchar not null,
    entry integer not null,
    primary key(source, filename, line, entry)
);

-- PubMed references (column 9)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_pubmed (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    pmid integer not null,
    entry integer not null,
    primary key(source, filename, line, entry)
);

-- Interaction type names (column 12)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_interaction_type_names (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    code varchar not null,
    name varchar not null,
    entry integer not null,
    primary key(source, filename, line, entry)
);

-- Sources (column 13)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_sources (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    sourcedb varchar not null,
    name varchar not null,
    entry integer not null,
    primary key(source, filename, line, entry)
);

-- Source interactions (column 14)
-- Experiment-related information (in MPIDB).
-- The entry column provides a counter related to the interaction.

create table mitab_interaction_identifiers (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    dbname varchar not null,
    "uid" varchar not null,
    entry integer not null,
    primary key(source, filename, interaction, line, entry)
);

-- Confidence scores (column 15)
-- Experiment-related information.
-- The entry column provides a counter related to the interaction.

create table mitab_confidence (
    source varchar not null,
    filename varchar not null,
    line integer not null,
    interaction varchar not null,
    "type" varchar not null,
    confidence integer not null,
    entry integer not null,
    primary key(source, filename, line, entry)
);

commit;
