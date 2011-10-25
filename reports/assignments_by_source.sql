begin;

-- Show the number of distinct assignments by data source.

create temporary table tmp_assignments_by_source as
    select source, count(distinct sequence) as total
    from irefindex_assignments
    group by source
    order by source;

\copy tmp_assignments_by_source to '<directory>/assignments_by_source'

-- Show the number of unassigned interactors by data source.

create temporary table tmp_unassigned_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
    from irefindex_unassigned
    group by source
    order by source;

\copy tmp_unassigned_by_source to '<directory>/unassigned_by_source'

rollback;
