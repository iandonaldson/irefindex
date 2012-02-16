begin;

create temporary table tmp_interaction_rogids as
    select source, filename, entry, interactionid, array_to_string(array_accum(rogid), '') as rogids
    from (
        select R.source, R.filename, R.entry, interactionid, rogid
        from xml_interactors as I
        inner join irefindex_rogids as R
            on (I.source, I.filename, I.entry, I.interactorid) =
                (R.source, R.filename, R.entry, R.interactorid)
        order by rogid
        ) as X
    group by source, filename, entry, interactionid;

\copy tmp_interaction_rogids to '<directory>/rogids_for_interactions'

rollback;
