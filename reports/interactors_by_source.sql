begin;

-- Show the number of distinct interactors by data source.

create temporary table tmp_interactors_by_source_and_sequence as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total, havesequence
    from (
        select source, filename, entry, interactorid,
            array_length(sequences, 1) = 1 and sequences[1] is null as havesequence
        from (
            select source, filename, entry, interactorid, array_accum(refsequence) as sequences
            from xml_xref_interactor_sequences
            group by source, filename, entry, interactorid
            ) as X
        ) as Y
    group by source, havesequence
    order by source, havesequence;

-- The output table has the following form:
--
-- <source> <total interactors> <total with sequence> <total without sequence>

create temporary table tmp_interactors_by_source as
    select coalesce(with_sequence.source, without_sequence.source) as source,
        coalesce(with_sequence.total, 0) + coalesce(without_sequence.total, 0) as total,
        coalesce(with_sequence.total, 0) as total_with_sequence,
        coalesce(without_sequence.total, 0) as total_without_sequence
    from (
        select source, total
        from tmp_interactors_by_source_and_sequence
        where havesequence
        ) as with_sequence
    full outer join (
        select source, total
        from tmp_interactors_by_source_and_sequence
        where not havesequence
        ) as without_sequence
        on with_sequence.source = without_sequence.source
    order by source;

\copy tmp_interactors_by_source to '<directory>/interactors_by_source'

rollback;
