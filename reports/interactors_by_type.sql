begin;

create temporary table tmp_interactors_by_type as
    select I.source, X.refvalue, count(distinct array[I.source, I.filename, cast(I.entry as varchar), I.interactorid]) as total
    from xml_xref_interactors as I
    left outer join xml_xref as X
        on (I.source, I.filename, I.entry, I.interactorid) = (X.source, X.filename, X.entry, X.parentid)
        and X.scope = 'interactor'
        and X.property = 'interactorType'
        and X.dblabel = 'psi-mi'
    group by I.source, X.refvalue
    order by I.source, X.refvalue;

\copy tmp_interactors_by_type to '<directory>/interactors_by_type'

rollback;
