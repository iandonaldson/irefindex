begin;

create temporary table tmp_rigids_by_source as
    select source, count(distinct rigid) as total
    from irefindex_rigids
    group by source order by source;

\copy tmp_rigids_by_source to '<directory>/rigids_by_source'

create temporary table tmp_source_rigids as
    select distinct rigid, source
    from irefindex_rigids;

analyze tmp_source_rigids;

create temporary table tmp_rigids_shared_by_sources as
    select R1.source as source1, R2.source as source2,
        count(distinct R1.rigid) as total
    from tmp_source_rigids as R1
    inner join tmp_source_rigids as R2
        on R1.rigid = R2.rigid
        and R1.source <= R2.source
    group by R1.source, R2.source
    order by R1.source, R2.source;

\copy tmp_rigids_shared_by_sources to '<directory>/rigids_shared_by_sources'

rollback;
