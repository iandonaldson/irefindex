begin;

create temporary table tmp_interactions_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactionid])
    from xml_interactors
    group by source
    order by source;

\copy tmp_interactions_by_source to '<directory>/interactions_by_source'

rollback;
