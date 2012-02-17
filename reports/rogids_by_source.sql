begin;

create temporary table tmp_rogids_by_source as
    select source, count(distinct rogid) as total
    from irefindex_rogids
    group by source order by source;

\copy tmp_rogids_by_source to '<directory>/rogids_by_source'

create temporary table tmp_source_rogids as
    select distinct rogid, source
    from irefindex_rogids;

analyze tmp_source_rogids;

create temporary table tmp_rogids_shared_by_sources as
    select R1.source as source1, R2.source as source2,
        count(distinct R1.rogid) as total
    from tmp_source_rogids as R1
    inner join tmp_source_rogids as R2
        on R1.rogid = R2.rogid
        and R1.source <= R2.source
    group by R1.source, R2.source
    order by R1.source, R2.source;

\copy tmp_rogids_shared_by_sources to '<directory>/rogids_shared_by_sources'

rollback;
