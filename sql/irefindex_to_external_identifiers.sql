begin;

-- Process the imported data.

-- Define the interactors, interactions and experiments in terms of their primary references.

create table irefindex_entities (
    source varchar not null,
    filename varchar not null,
    scope varchar not null,
    parentid integer not null,
    db varchar not null,
    acc varchar not null
);

insert into irefindex_entities
    select distinct source, filename, scope, parentid, dblabel, refvalue
    from xml_xref
    where property = scope -- the reference must describe the entity itself
        and reftype = 'primaryRef';

alter table irefindex_entities add primary key (source, filename, scope, parentid, db, acc);
analyze irefindex_entities;

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

insert into irefindex_names
    select A.source, A.scope, A.db, A.acc,
        B.nametype, B.typelabel, B.typecode, name
    from irefindex_entities as A
    inner join xml_names as B
        on A.source = B.source
        and A.filename = B.filename
        and A.parentid = B.parentid
        and A.scope = B.scope
        and B.property = B.scope;

analyze irefindex_names;

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

insert into irefindex_xref
    select A.source, A.scope, A.db, A.acc,
        B.reftype, B.refvalue, B.dblabel, B.dbcode, B.reftypelabel, B.reftypecode
    from irefindex_entities as A
    inner join xml_xref as B
        on A.source = B.source
        and A.filename = B.filename
        and A.parentid = B.parentid
        and A.scope = B.scope
        and B.property = B.scope;

analyze irefindex_xref;

-- Map the interactors to interactions using primary references.

create table irefindex_interactors (
    source varchar not null,
    db varchar not null,
    acc varchar not null,
    interactiondb varchar not null,
    interactionacc varchar not null,
    participantid integer not null -- distinguishes between participants
);

insert into irefindex_interactors
    select A.source, A.db, A.acc,
        B.db as interactiondb, B.acc as interactionacc,
        P.participantid
    from irefindex_entities as A
    inner join xml_interactors as I
        on A.source = I.source
        and A.filename = I.filename
        and A.parentid = I.interactorid
        and A.scope = 'interactor'
    inner join xml_participants as P
        on I.source = P.source
        and I.filename = P.filename
        and I.participantid = P.participantid
    inner join irefindex_entities as B
        on B.source = P.source
        and B.filename = P.filename
        and B.parentid = P.interactionid
        and B.scope = 'interaction';

analyze irefindex_interactors;

-- Map the experiments to interactions using primary references.

create table irefindex_experiments (
    source varchar not null,
    db varchar not null,
    acc varchar not null,
    experimentdb varchar not null,
    experimentacc varchar not null
);

insert into irefindex_experiments
    select A.source, A.db, A.acc,
        B.db as interactiondb, B.acc as interactionacc
    from irefindex_entities as A
    inner join xml_experiments as I
        on A.source = I.source
        and A.filename = I.filename
        and A.parentid = I.experimentid
        and A.scope = 'experimentDescription'
    inner join irefindex_entities as B
        on B.source = I.source
        and B.filename = I.filename
        and B.parentid = I.interactionid
        and B.scope = 'interaction';

analyze irefindex_experiments;

commit;
