begin;

-- Show the number of distinct identifiers by database.

create temporary table tmp_identifiers_by_database as
    select dblabel, count(distinct refvalue) as total, havesequence
    from (
        select dblabel, refvalue, refsequence is not null as havesequence
        from xml_xref_interactor_sequences
        ) as X
    group by dblabel, havesequence
    order by dblabel, havesequence;

\copy tmp_identifiers_by_database to '<directory>/identifiers_by_database'

-- Show the number of distinct interactors by data source.

create temporary table tmp_interactors_by_source_and_sequence as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total, havesequence
    from (
        select source, filename, entry, interactorid, sequences <> 0 as havesequence
        from (
            select source, filename, entry, interactorid, count(distinct refsequence) as sequences
            from xml_xref_interactor_sequences
            group by source, filename, entry, interactorid
            ) as X
        ) as Y
    group by source, havesequence
    order by source, havesequence;

-- The output table has the following form:
--
-- <source> <total interactors> <total usable interactors> <total with sequence> <total without sequence>

create temporary table tmp_interactors_by_source as
    select X.source, X.total as full_total,
        coalesce(with_sequence.total, 0) + coalesce(without_sequence.total, 0) as total,
        coalesce(with_sequence.total, 0) as total_with_sequence,
        coalesce(without_sequence.total, 0) as total_without_sequence
    from (
        select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
        from xml_xref_all_interactors
        group by source
        ) as X
    left outer join (
        select source, total
        from tmp_interactors_by_source_and_sequence
        where havesequence
        ) as with_sequence
        on X.source = with_sequence.source
    left outer join (
        select source, total
        from tmp_interactors_by_source_and_sequence
        where not havesequence
        ) as without_sequence
        on X.source = without_sequence.source
    order by X.source;

\copy tmp_interactors_by_source to '<directory>/interactors_by_source'

rollback;
