begin;

create temporary table tmp_assignments_by_taxid as
    select A.taxid, name, count(distinct array[source, filename, cast(entry as varchar), interactorid]) as interactors, count(distinct sequence) as sequences
    from irefindex_assignments as A
    left outer join taxonomy_names as T
        on A.taxid = T.taxid
        and nameclass = 'scientific name'
    group by A.taxid, name
    order by interactors desc, sequences desc;

\copy tmp_assignments_by_taxid to '<directory>/assignments_by_taxid'

rollback;
