begin;

-- Note that the ordering requires an appropriate locale.

create temporary table tmp_interaction_rogids_canonical as
    select distinct rigid, rogids
    from (
        select rigid, array_to_string(array_accum(rogid), '') as rogids
        from (

            -- Select all ROG identifiers, which can include the same ROG identifier
            -- for multiple participants.

            select source, filename, entry, interactionid, rigid, rogid
            from irefindex_interactions

            order by source, filename, entry, interactionid, rigid, rogid -- collate "C" for PostgreSQL 9.1
            ) as X

        group by source, filename, entry, interactionid, rigid
        ) as Y;

\copy tmp_interaction_rogids_canonical to '<directory>/rogids_for_interactions_canonical'

rollback;
