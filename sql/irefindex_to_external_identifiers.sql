begin;

-- Process the imported data.

-- Define the interactors, interactions and experiments in terms of their primary references.

insert into irefindex_entities
    select distinct source, filename, scope, parentid, dblabel, refvalue, 'external'
    from xml_xref
    where -- for interactions and interactors, the reference must describe the entity itself
        property = scope
        and reftype = 'primaryRef'
        or -- for experiments, the a bibliographic reference is used
        property = 'bibref'
        and scope = 'experimentDescription'
        and reftype = 'primaryRef';

analyze irefindex_entities;

-- Provide an arbitrary internal identifier for interactors and interactions with no primary reference.

insert into irefindex_entities
    select source, filename, 'interactor', interactorid, source, nextval('irefindex_interactorid'), 'internal'
    from (
        select distinct I.source, I.filename, I.interactorid
        from xml_interactors as I
        left outer join irefindex_entities as X
            on I.source = X.source
            and I.filename = X.filename
            and X.scope = 'interactor'
            and I.interactorid = X.parentid
        where X.parentid is null
        ) as Y;

insert into irefindex_entities
    select source, filename, 'interaction', interactionid, source, nextval('irefindex_interactionid'), 'internal'
    from (
        select distinct I.source, I.filename, I.interactionid
        from xml_interactors as I
        left outer join irefindex_entities as X
            on I.source = X.source
            and I.filename = X.filename
            and X.scope = 'interaction'
            and I.interactionid = X.parentid
        where X.parentid is null
        ) as Y;

analyze irefindex_entities;

-- Associate the names and xrefs with the primary references.

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

insert into irefindex_interactors
    select A.source, A.db, A.acc,
        B.db as interactiondb, B.acc as interactionacc,
        I.participantid
    from irefindex_entities as A
    inner join xml_interactors as I
        on A.source = I.source
        and A.filename = I.filename
        and A.parentid = I.interactorid
        and A.scope = 'interactor'
    inner join irefindex_entities as B
        on B.source = I.source
        and B.filename = I.filename
        and B.parentid = I.interactionid
        and B.scope = 'interaction';

analyze irefindex_interactors;

-- Map the experiments to interactions using primary references.

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
