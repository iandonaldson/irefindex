begin;

-- Show the number of distinct interactors by data source.

create temporary table tmp_interactors_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total, havesequence
    from (
        select source, filename, entry, interactorid, case
            when refsequence is null then false
            else true end as havesequence
        from xml_xref_interactor_sequences
        ) as X
    group by source, havesequence
    order by source, havesequence;

\copy tmp_interactors_by_source to '<directory>/interactors_by_source'

rollback;
