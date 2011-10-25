begin;

-- Show the number of distinct interactors by data source.

create temporary table tmp_interactors_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
    from xml_xref_sequences
    group by source
    order by source;

\copy tmp_interactors_by_source to '<directory>/interactors_by_source'

rollback;
