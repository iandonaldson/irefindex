begin;

-- Define the interactors, interactions and experiments in terms of their primary references.

create table irefindex_entities (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    db varchar not null,
    acc varchar not null,
    reftype varchar not null,
    primary key (source, filename, scope, parentid, db, acc)
);

-- Sequences for internal references where no external references can be found.

create sequence irefindex_interactorid;
create sequence irefindex_interactionid;
create sequence irefindex_experimentid;

-- Associate the names and xrefs with the primary references.

create table irefindex_names (
    source varchar not null,
    scope varchar not null,
    db varchar not null,
    acc varchar not null,
    nametype varchar not null,
    typelabel varchar,
    typecode varchar,
    name varchar not null
);

create table irefindex_xref (
    source varchar not null,
    scope varchar not null,
    db varchar not null,
    acc varchar not null,
    reftype varchar not null,
    refvalue varchar not null,
    dblabel varchar,
    dbcode varchar,
    reftypelabel varchar,
    reftypecode varchar
);

-- Map the interactors to participants to interactions using primary references.

create table irefindex_interactors (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null, -- integer for PSI MI XML 2.5
    db varchar not null,
    acc varchar not null,
    interactiondb varchar not null,
    interactionacc varchar not null,
    participantid varchar not null -- integer for PSI MI XML 2.5
);

-- Map the experiments to interactions using primary references.

create table irefindex_experiments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null, -- integer for PSI MI XML 2.5
    db varchar not null,
    acc varchar not null,
    interactiondb varchar not null,
    interactionacc varchar not null
);

commit;
