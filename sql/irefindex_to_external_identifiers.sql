begin;

-- Process the imported data.

-- Define the interactors, interactions and experiments in terms of their primary references.

create table irefindex_entities as
    select distinct source, filename, scope, parentid, dblabel, refvalue
    from tmp_xref
    where property = scope -- the reference must describe the entity itself
        and reftype = 'primaryRef';

analyze irefindex_entities;

-- Associate the names and xrefs with the primary references.

create table irefindex_names as
    select A.dblabel as db, A.refvalue as acc,
        B.nametype, B.typelabel, B.typecode, name,
        A.source, A.filename, A.scope, A.parentid
    from irefindex_entities as A
    inner join tmp_names as B
        on A.source = B.source
        and A.filename = B.filename
        and A.parentid = B.parentid
        and A.scope = B.scope
        and B.property = B.scope;

analyze irefindex_names;

create table irefindex_xref as
    select A.dblabel as db, A.refvalue as acc,
        B.reftype, B.refvalue, B.dblabel, B.dbcode, B.reftypelabel, B.reftypecode,
        A.source, A.filename, A.scope, A.parentid
    from irefindex_entities as A
    inner join tmp_xref as B
        on A.source = B.source
        and A.filename = B.filename
        and A.parentid = B.parentid
        and A.scope = B.scope
        and B.property = B.scope;

analyze irefindex_xref;

-- Map the interactors and experiments to interactions using primary references.

create table irefindex_interactors as
    select A.dblabel as db, A.refvalue as acc,
        B.dblabel as interactiondb, B.refvalue as interactionacc,
        A.source, A.filename
    from irefindex_entities as A
    inner join tmp_interactors as I
        on A.source = I.source
        and A.filename = I.filename
        and A.parentid = I.interactorid
        and A.scope in ('participant', 'interactor')
    inner join irefindex_entities as B
        on B.source = I.source
        and B.filename = I.filename
        and B.parentid = I.interactionid
        and B.scope = 'interaction';

analyze irefindex_interactors;

create table irefindex_experiments as
    select A.dblabel as db, A.refvalue as acc,
        B.dblabel as interactiondb, B.refvalue as interactionacc,
        A.source, A.filename
    from irefindex_entities as A
    inner join tmp_experiments as I
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
