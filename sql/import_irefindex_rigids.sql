begin;

\copy irefindex_rigids from '<directory>/rigids_for_interactions'
analyze irefindex_rigids;

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

commit;
