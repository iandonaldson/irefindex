begin;

-- Note that the ordering is done in the signature/digest processing.

create temporary table tmp_interaction_rogids as
    select source, filename, entry, interactionid, array_to_string(array_accum(rogid), ',') as rogids
    from (

        -- Select all ROG identifiers, which can include the same ROG identifier
        -- for multiple participants.

        select R.source, R.filename, R.entry, interactionid, rogid
        from xml_interactors as I
        inner join irefindex_rogids as R
            on (I.source, I.filename, I.entry, I.interactorid) =
                (R.source, R.filename, R.entry, R.interactorid)
        ) as X

    group by source, filename, entry, interactionid;

\copy tmp_interaction_rogids to '<directory>/rogids_for_interactions'

rollback;
