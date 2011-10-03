begin;

create temporary table tmp_sources_with_ambiguous_primary_references as
    select source, sequences
    from (
        select source, filename, entry, interactorid, count(distinct sequence) as sequences
        from xml_xref_sequences
        where reftype = 'primaryRef'
        group by source, filename, entry, interactorid
        ) as X
    group by source, sequences;

create temporary table tmp_array_of_sources_with_ambiguous_primary_references as
    select sequences, array_accum(source) as sources
    from tmp_sources_with_ambiguous_primary_references
    group by sequences
    order by sequences;

\copy tmp_array_of_sources_with_ambiguous_primary_references to '<directory>/sources_with_ambiguous_primary_references.txt'

create temporary table tmp_dblabels_with_ambiguous_primary_references as
    select sequences, array_accum(dblabel) as dblabels
    from (
        select dblabel, sequences
        from (
            select source, filename, entry, interactorid, count(distinct sequence) as sequences
            from xml_xref_sequences
            where reftype = 'primaryRef'
            group by source, filename, entry, interactorid
            ) as X
        inner join xml_xref_sequences as X2
            on X.source = X2.source
            and X.filename = X2.filename
            and X.entry = X2.entry
            and X.interactorid = X2.interactorid
        group by dblabel, sequences
    ) as Y
    group by sequences
    order by sequences;

\copy tmp_dblabels_with_ambiguous_primary_references to '<directory>/dblabels_with_ambiguous_primary_references.txt'

create temporary table tmp_examples_of_ambiguous_primary_references as
    select S.sequences, count(*) as interactors, min(array[X.source, filename, cast(entry as varchar), interactorid]) as example
    from (
        select source, filename, entry, interactorid, count(distinct sequence) as sequences
        from xml_xref_sequences
        where reftype = 'primaryRef'
        group by source, filename, entry, interactorid
        ) as X
    inner join tmp_sources_with_ambiguous_primary_references as S
        on X.source = S.source
        and X.sequences = S.sequences
    group by S.sequences, S.source
    order by S.sequences, S.source;

\copy tmp_examples_of_ambiguous_primary_references to '<directory>/examples_of_ambiguous_primary_references.txt'

rollback;
