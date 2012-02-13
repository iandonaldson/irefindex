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
    select source, havesequence, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
    from (
        select source, filename, entry, interactorid,
            case when sequence is null then false else true end as havesequence
        from irefindex_unassigned
        where refsequences = 0
        ) as X
    group by source, havesequence
    order by source, havesequence;

\copy tmp_unassigned_by_source to '<directory>/unassigned_by_source'

-- Show the number of unassigned interactors by source and type.

create temporary table tmp_unassigned_by_source_and_type as
    select I.source, X.refvalue, count(distinct array[I.source, I.filename, cast(I.entry as varchar), I.interactorid])
    from irefindex_unassigned as U
    inner join xml_xref_interactors as I
        on (I.source, I.filename, I.entry, I.interactorid) = (U.source, U.filename, U.entry, U.interactorid)
    left outer join xml_xref as X
        on (I.source, I.filename, I.entry, I.interactorid) = (X.source, X.filename, X.entry, X.parentid)
        and X.scope = 'interactor' and X.property = 'interactorType' and X.dblabel = 'psi-mi'
    where refsequences = 0
    group by I.source, X.refvalue
    order by I.source, X.refvalue;

\copy tmp_unassigned_by_source_and_type to '<directory>/unassigned_by_source_and_type'

-- Show the number of unassigned interactors by number of sequences.

create temporary table tmp_unassigned_by_sequences as
    select sequence, refsequences, count(distinct array[source, filename, cast(entry as varchar), interactorid]) as total
    from irefindex_unassigned
    group by sequence, refsequences
    order by sequence, refsequences;

\copy tmp_unassigned_by_sequences to '<directory>/unassigned_by_sequences'

-- Show the coverage of each source (like Table 3 from the iRefIndex paper).
-- The output table has the following form:
--
-- <source> <total interactors> <total assignments> <total unassigned> <percent assigned> <assignable> <unassignable> <unique proteins>

create temporary table tmp_assignment_coverage as
    select coalesce(assigned.source, assignable.source, unassignable.source) as source,

        -- Total interactors.
        coalesce(assigned.total, 0) + coalesce(assignable.total, 0) + coalesce(unassignable.total, 0) as total,
        -- Total assignments.
        coalesce(assigned.total, 0) as assigned_total,
        -- Total unassigned.
        coalesce(assignable.total, 0) + coalesce(unassignable.total, 0) as unassigned_total,
        -- Percent coverage.
        round(
            cast(
                cast(coalesce(assigned.total, 0) as real) / (coalesce(assignable.total, 0) + coalesce(unassignable.total, 0) + coalesce(assigned.total, 0)) * 100
                as numeric
                ), 2
            ) as coverage,
        -- Assignable.
        coalesce(assignable.total, 0) as assignable_total,
        -- Unassignable.
        coalesce(unassignable.total, 0) as unassignable_total,
        -- Unique proteins.
        coalesce(sequences.total, 0) as sequences_total

    from tmp_assignments_by_source as assigned
    full outer join (
        select source, total
        from tmp_unassigned_by_source
        where havesequence
        ) as assignable
        on assigned.source = assignable.source
    full outer join (
        select source, total
        from tmp_unassigned_by_source
        where not havesequence
        ) as unassignable
        on assigned.source = unassignable.source
    full outer join tmp_sequences_by_source as sequences
        on assigned.source = sequences.source
    order by coalesce(assigned.source, assignable.source, unassignable.source);

\copy tmp_assignment_coverage to '<directory>/assignment_coverage_by_source'

rollback;
