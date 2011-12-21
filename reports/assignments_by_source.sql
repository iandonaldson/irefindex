begin;

-- Show the number of distinct assignments by data source.

create temporary table tmp_sequences_by_source as
    select source, count(distinct sequence) as total
    from irefindex_assignments
    group by source
    order by source;

\copy tmp_sequences_by_source to '<directory>/sequences_by_source'

create temporary table tmp_assignments_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
    from irefindex_assignments
    group by source
    order by source;

\copy tmp_assignments_by_source to '<directory>/assignments_by_source'

-- Show the number of unassigned interactors by data source.

create temporary table tmp_unassigned_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total, havesequences
    from (
        select source, filename, entry, interactorid,
            case when refsequences = 0 then false
            else true
            end as havesequences
        from irefindex_unassigned
        ) as X
    group by source, havesequences
    order by source, havesequences;

\copy tmp_unassigned_by_source to '<directory>/unassigned_by_source'

-- Show the number of unassigned interactors by number of sequences.

create temporary table tmp_unassigned_by_sequences as
    select sequences, refsequences, count(distinct array[source, filename, cast(entry as varchar), interactorid]) as total
    from irefindex_unassigned
    group by sequences, refsequences
    order by sequences, refsequences;

\copy tmp_unassigned_by_sequences to '<directory>/unassigned_by_sequences'

rollback;
