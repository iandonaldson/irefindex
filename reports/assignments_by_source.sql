begin;

-- Show the number of distinct assignments by data source.
-- NOTE: This uses rogids instead of sequences because an ultimately successful
-- NOTE: assignment involves both the sequence and taxid as a rogid.

create temporary table tmp_rogids_by_source as
    select source, count(distinct rogid) as total
    from irefindex_rogids
    group by source
    order by source;

\copy tmp_rogids_by_source to '<directory>/rogids_by_source'

-- Show the number of distinct interactor identifiers by data source.

create temporary table tmp_assigned_identifiers_by_source_and_method as
    select R.source, R.method, count(distinct array[S.dblabel, S.refvalue]) as total
    from irefindex_rogids as R
    inner join xml_xref_interactor_sequences as S
        on (R.source, R.filename, R.entry, R.interactorid) =
            (S.source, S.filename, S.entry, S.interactorid)
    group by R.source, R.method
    order by R.source, R.method;

\copy tmp_assigned_identifiers_by_source_and_method to '<directory>/assigned_identifiers_by_source_and_method'

-- Show the number of distinct interactor participants by data source.

create temporary table tmp_assigned_interactors_by_source_and_method as
    select R.source, R.method, count(distinct array[R.source, R.filename, cast(R.entry as varchar), R.interactorid]) as total
    from irefindex_rogids as R
    group by R.source, R.method
    order by R.source, R.method;

\copy tmp_assigned_interactors_by_source_and_method to '<directory>/assigned_interactors_by_source_and_method'

-- Show the number of unassigned interactor identifiers by data source.

create temporary table tmp_unassigned_identifiers_by_source as
    select U.source, count(distinct array[S.dblabel, S.refvalue]) as total
    from irefindex_unassigned as U
    inner join xml_xref_interactor_sequences as S
        on (U.source, U.filename, U.entry, U.interactorid) =
            (S.source, S.filename, S.entry, S.interactorid)
    group by U.source
    order by U.source;

\copy tmp_unassigned_identifiers_by_source to '<directory>/unassigned_identifiers_by_source'

-- Show the number of unassigned interactor participants by data source.

create temporary table tmp_unassigned_interactors_by_source as
    select U.source, count(distinct array[U.source, U.filename, cast(U.entry as varchar), U.interactorid]) as total
    from irefindex_unassigned as U
    group by U.source
    order by U.source;

\copy tmp_unassigned_interactors_by_source to '<directory>/unassigned_interactors_by_source'

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
-- <source> <total interactors> <total assignments> <percent assigned> <arbitrary> <matching sequence> <interactor sequence> <total unassigned> <unique proteins>

create temporary table tmp_assignment_coverage as
    select
        -- Source.
        coalesce(assigned.source, unassigned.source) as source,
        -- Total interactors.
        coalesce(assigned.total, 0) + coalesce(unassigned.total, 0) as total,
        -- Total assignments.
        coalesce(assigned.total, 0) as assigned_total,
        -- Percent coverage.
        round(
            cast(
                cast(coalesce(assigned.total, 0) as real) / (coalesce(unassigned.total, 0) + coalesce(assigned.total, 0)) * 100
                as numeric
                ), 2
            ) as coverage,
        -- Arbitrary.
        coalesce(arbitrary.total, 0) as arbitrary_total,
        -- Matching interactor sequence.
        coalesce(matching_sequence.total, 0) as matching_sequence_total,
        -- Interactor sequence only.
        coalesce(interactor_sequence.total, 0) as interactor_sequence_total,
        -- Total unassigned.
        coalesce(unassigned.total, 0) as unassigned_total,
        -- Unique proteins.
        coalesce(rogids.total, 0) as rogids_total

    from (
        select source, sum(total) as total
        from tmp_assigned_interactors_by_source_and_method
        group by source
        ) as assigned
    full outer join (
        select source, total
        from tmp_assigned_interactors_by_source_and_method
        where method = 'matching sequence'
        ) as matching_sequence
        on assigned.source = matching_sequence.source
    full outer join (
        select source, total
        from tmp_assigned_interactors_by_source_and_method
        where method = 'interactor sequence'
        ) as interactor_sequence
        on assigned.source = interactor_sequence.source
    full outer join (
        select source, total
        from tmp_assigned_interactors_by_source_and_method
        where method = 'arbitrary'
        ) as arbitrary
        on assigned.source = arbitrary.source
    full outer join (
        select source, sum(total) as total
        from tmp_unassigned_interactors_by_source
        group by source
        ) as unassigned
        on assigned.source = unassigned.source
    full outer join tmp_rogids_by_source as rogids
        on assigned.source = rogids.source
    order by coalesce(assigned.source, unassigned.source);

\copy tmp_assignment_coverage to '<directory>/assignment_coverage_by_source'

-- Show the above coverage with headings for display using...
--
-- column -s $'\t' -t rogid_coverage_by_source

create temporary table tmp_rogid_coverage as

    -- Add a header and totals.

    select 'Source' as source, 'Protein interactors' as total, 'Assigned' as assigned_total, '%' as coverage,
        'Arbitrary' as arbitrary_total, 'Matching sequence' as matching_sequence_total,
        'Interactor sequence' as interactor_sequence_total, 'Unassigned' as unassigned_total,
        'Unique proteins' as rogids_total
    union all
    select source, cast(total as varchar), cast(assigned_total as varchar), cast(coverage as varchar),
        cast(arbitrary_total as varchar), cast(matching_sequence_total as varchar),
        cast(interactor_sequence_total as varchar), cast(unassigned_total as varchar),
        cast(rogids_total as varchar)
    from tmp_assignment_coverage
    union all
    select '(All)' as source,
        cast(sum(total) as varchar),
        cast(sum(assigned_total) as varchar),
        cast(round(cast(cast(sum(assigned_total) as real) / (sum(assigned_total) + sum(unassigned_total)) * 100 as numeric), 2) as varchar),
        cast(sum(arbitrary_total) as varchar),
        cast(sum(matching_sequence_total) as varchar),
        cast(sum(interactor_sequence_total) as varchar),
        cast(sum(unassigned_total) as varchar),
        cast(sum(rogids_total) as varchar)
    from tmp_assignment_coverage;

\copy tmp_rogid_coverage to '<directory>/rogid_coverage_by_source'

rollback;
