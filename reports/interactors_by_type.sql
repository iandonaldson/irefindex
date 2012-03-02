begin;

create temporary table tmp_interactors_by_type as
    select I.source, X.refvalue, min(name), count(distinct array[I.source, I.filename, cast(I.entry as varchar), I.interactorid]) as total
    from xml_xref_interactors as I
    left outer join xml_xref_interactor_types as X
        on (I.source, I.filename, I.entry, I.interactorid) = (X.source, X.filename, X.entry, X.interactorid)
    left outer join psicv_terms as T
        on X.refvalue = T.code
    group by I.source, X.refvalue
    order by I.source, X.refvalue;

\copy tmp_interactors_by_type to '<directory>/interactors_by_type'

rollback;
