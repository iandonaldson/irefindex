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

create temporary table tmp_rogids_unique_to_sources as
    select R1.source, count(distinct R1.rogid) as total
    from tmp_source_rogids as R1
    left outer join tmp_source_rogids as R2
        on R1.rogid = R2.rogid
        and R1.source <> R2.source
    where R2.rogid is null
    group by R1.source
    order by R1.source;

\copy tmp_rogids_unique_to_sources to '<directory>/rogids_unique_to_sources'

-- Make a grid that can be displayed using...
-- column -s ',' -t rogids_shared_as_grid

create temporary table tmp_rogids_shared_as_grid as

    -- Make a header.

    select array_to_string(array_cat(array[cast('-' as varchar)], array_accum(source)), ',')
    from tmp_rogids_by_source
    union all (

        -- Make each row with the source in the first column.

        select array_to_string(array_cat(array[source1], array_accum(coalesce(cast(total as varchar), '-'))), ',')
        from (
            select S.source1, S.source2, R.total
            from tmp_rogids_shared_by_sources as R
            right outer join (
                select S1.source as source1, S2.source as source2
                from tmp_rogids_by_source as S1
                cross join tmp_rogids_by_source as S2
                ) as S
                on R.source1 = S.source1
                and R.source2 = S.source2
            order by S.source1, S.source2
            ) as X
        group by source1
        order by source1
        )
    union all

    -- Make a row with unique identifier totals.

    select array_to_string(array_cat(array[cast('-' as varchar)], array_accum(coalesce(cast(total as varchar), '-'))), ',')
    from tmp_rogids_unique_to_sources;

\copy tmp_rogids_shared_as_grid to '<directory>/rogids_shared_as_grid'

rollback;