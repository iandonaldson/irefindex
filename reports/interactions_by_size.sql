begin;

create temporary table tmp_interaction_sizes as
    select participants, count(distinct array[source, filename, cast(entry as varchar), interactionid]) as total
    from (
        select source, filename, entry, interactionid, count(interactorid) as participants
        from xml_interactors
        group by source, filename, entry, interactionid
        ) as X
    group by participants
    order by participants;

\copy tmp_interaction_sizes to '<directory>/interactions_by_size'

rollback;
