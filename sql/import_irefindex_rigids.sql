begin;

\copy irefindex_rigids from '<directory>/rigids_for_interactions'
analyze irefindex_rigids;

-- A mapping from RIG identifiers to ROG identifiers for complete interactions.

insert into irefindex_interactions
    select I.source, I.filename, I.entry, O.interactorid, X.participantid, I.interactionid, O.rogid, I.rigid
    from irefindex_rigids as I
    inner join xml_interactors as X
        on (I.source, I.filename, I.entry, I.interactionid) =
           (X.source, X.filename, X.entry, X.interactionid)
    inner join irefindex_rogids as O
        on (X.source, X.filename, X.entry, X.interactorid) =
           (O.source, O.filename, O.entry, O.interactorid);

analyze irefindex_interactions;

-- A mapping from RIG identifiers to ROG identifiers without reference to
-- specific interactions.

insert into irefindex_distinct_interactions
    select rigid, rogid
    from (
        select min(array[source, filename, cast(entry as varchar), interactionid]) as first
        from irefindex_interactions
        group by rigid
        ) as X
    inner join irefindex_interactions as I
        on X.first = array[I.source, I.filename, cast(I.entry as varchar), I.interactionid];

create index irefindex_distinct_interactions_rigid on irefindex_distinct_interactions(rigid);
analyze irefindex_distinct_interactions;

commit;
