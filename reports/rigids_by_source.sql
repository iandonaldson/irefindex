begin;

create temporary table tmp_rigids_by_source as
    select source, count(distinct rigid) as total
    from irefindex_rigids
    group by source order by source;

\copy tmp_rigids_by_source to '<directory>/rigids_by_source'

rollback;
