begin;

-- Process the imported data.

-- Define the interactors, interactions and experiments in terms of their primary references.

insert into irefindex_entities
    select distinct source, filename, entry, scope, parentid, dblabel, refvalue, 'external'
    from xml_xref
    where -- the reference must describe the entity itself
        property = scope
        and reftype = 'primaryRef';

analyze irefindex_entities;

-- Attempt to add bibliographical references for experiments if no specific references exist.

insert into irefindex_entities
    select distinct I.source, I.filename, I.entry, X.scope, X.parentid, dblabel, refvalue, 'external'
    from xml_experiments as I
    inner join xml_xref as X
        on I.source = X.source
        and I.filename = X.filename
        and I.entry = X.entry
        and I.experimentid = X.parentid
        and property = 'bibref'
        and reftype = 'primaryref'
    left outer join irefindex_entities as E
        on I.source = E.source
        and I.filename = E.filename
        and I.entry = E.entry
        and X.scope = E.scope
        and I.experimentid = E.parentid
    where X.scope = 'experimentDescription'
        and E.parentid is null;

-- Provide an arbitrary internal identifier for interactors and interactions with no primary reference.

insert into irefindex_entities
    select source, filename, entry, 'interactor', interactorid, source, nextval('irefindex_interactorid'), 'internal'
    from (
        select distinct I.source, I.filename, I.entry, I.interactorid
        from xml_interactors as I
        left outer join irefindex_entities as X
            on I.source = X.source
            and I.filename = X.filename
            and I.entry = X.entry
            and X.scope = 'interactor'
            and I.interactorid = X.parentid
        where X.parentid is null
        ) as Y;

insert into irefindex_entities
    select source, filename, entry, 'interaction', interactionid, source, nextval('irefindex_interactionid'), 'internal'
    from (
        select distinct I.source, I.filename, I.entry, I.interactionid
        from xml_interactors as I
        left outer join irefindex_entities as X
            on I.source = X.source
            and I.filename = X.filename
            and I.entry = X.entry
            and X.scope = 'interaction'
            and I.interactionid = X.parentid
        where X.parentid is null
        ) as Y;

insert into irefindex_entities
    select source, filename, entry, 'experimentDescription', experimentid, source, nextval('irefindex_experimentid'), 'internal'
    from (
        select distinct I.source, I.filename, I.entry, I.experimentid
        from xml_experiments as I
        left outer join irefindex_entities as X
            on I.source = X.source
            and I.filename = X.filename
            and I.entry = X.entry
            and X.scope = 'experimentDescription'
            and I.experimentid = X.parentid
        where X.parentid is null
        ) as Y;

analyze irefindex_entities;

-- Map the interactors to interactions using primary references.

insert into irefindex_interactors
    select I.source, I.filename, I.entry, interactorid, interactionid, A.db, A.acc, B.db, B.acc, participantid
    from irefindex_entities as A
    inner join xml_interactors as I
        on A.source = I.source
        and A.filename = I.filename
        and A.entry = I.entry
        and A.parentid = I.interactorid
        and A.scope = 'interactor'
    inner join irefindex_entities as B
        on B.source = I.source
        and B.filename = I.filename
        and B.entry = I.entry
        and B.parentid = I.interactionid
        and B.scope = 'interaction';

analyze irefindex_interactors;

-- Map the experiments to interactions using primary references.

insert into irefindex_experiments
    select I.source, I.filename, I.entry, experimentid, interactionid, A.db, A.acc, B.db, B.acc
    from irefindex_entities as A
    inner join xml_experiments as I
        on A.source = I.source
        and A.filename = I.filename
        and A.entry = I.entry
        and A.parentid = I.experimentid
        and A.scope = 'experimentDescription'
    inner join irefindex_entities as B
        on B.source = I.source
        and B.filename = I.filename
        and B.entry = I.entry
        and B.parentid = I.interactionid
        and B.scope = 'interaction';

analyze irefindex_experiments;

commit;
