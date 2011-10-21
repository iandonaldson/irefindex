begin;

-- Show the number of distinct interactors by data source.

create temporary table tmp_interactors_by_source as
    select source, count(distinct sequence) as total
    from irefindex_assignments
    group by source
    order by source;

\copy tmp_interactors_by_source to '<directory>/interactors_by_source'

rollback;
