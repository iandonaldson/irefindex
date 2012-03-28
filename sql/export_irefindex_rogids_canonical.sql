begin;

-- Note that the ordering requires an appropriate locale.

create temporary table tmp_interaction_rogids_canonical as
    select distinct rigid, crogids
    from (
        select rigid, array_to_string(array_accum(crogid), '') as crogids
        from (

            -- Select all ROG identifiers, which can include the same ROG identifier
            -- for multiple participants.

            select source, filename, entry, interactionid, rigid, crogid
            from irefindex_interactions as I
            inner join irefindex_rogids_canonical as C
                on I.rogid = C.rogid

            order by source, filename, entry, interactionid, rigid, crogid -- collate "C" for PostgreSQL 9.1
            ) as X

        group by source, filename, entry, interactionid, rigid
        ) as Y;

\copy tmp_interaction_rogids_canonical to '<directory>/rogids_for_interactions_canonical'

rollback;
