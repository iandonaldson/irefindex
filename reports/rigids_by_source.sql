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

-- Make a grid that can be displayed using...
-- column -s ',' -t rigids_shared_as_grid

create temporary table tmp_rigids_shared_as_grid as

    -- Make a header.

    select array_to_string(array_cat(array[cast('-' as varchar)], array_accum(source)), ',')
    from tmp_rigids_by_source
    union all (

        -- Make each row with the source in the first column.

        select array_to_string(array_cat(array[source1], array_accum(coalesce(cast(total as varchar), '-'))), ',')
        from (
            select S.source1, S.source2, R.total
            from tmp_rigids_shared_by_sources as R
            right outer join (
                select S1.source as source1, S2.source as source2
                from tmp_rigids_by_source as S1
                cross join tmp_rigids_by_source as S2
                ) as S
                on R.source1 = S.source1
                and R.source2 = S.source2
            order by S.source1, S.source2
            ) as X
        group by source1
        order by source1
    );

\copy tmp_rigids_shared_as_grid to '<directory>/rigids_shared_as_grid'

rollback;
