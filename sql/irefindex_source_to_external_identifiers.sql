begin;

-- Process the imported data.

-- Define the interactors, interactions and experiments in terms of their primary references.

insert into irefindex_entities
    select distinct source, filename, scope, parentid, dblabel, refvalue
    from xml_xref
    where (
        -- for interactions and interactors, the reference must describe the entity itself
        property = scope
        and reftype = 'primaryRef'
        or -- for experiments, the a bibliographic reference is used
        property = 'bibref'
        and scope = 'experimentDescription'
        and reftype = 'primaryRef'
        )
        and source = '<source>';

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
        and B.property = B.scope
    where A.source = '<source>';

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
        and B.property = B.scope
    where A.source = '<source>';

analyze irefindex_xref;

-- Map the interactors to interactions using primary references.

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
        and B.scope = 'interaction'
    where A.source = '<source>';

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
        and B.scope = 'interaction'
    where A.source = '<source>';

analyze irefindex_experiments;

commit;
