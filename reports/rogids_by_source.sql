begin;

create temporary table tmp_rogids_by_source as
    select source, count(distinct rogid) as total
    from irefindex_rogids
    group by source order by source;

\copy tmp_rogids_by_source to '<directory>/rogids_by_source'

rollback;
