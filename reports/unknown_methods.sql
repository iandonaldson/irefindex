begin;

create temporary table tmp_unknown_methods as
    select I.refvalue, count(*) as total
    from xml_xref_experiment_methods as I
    left outer join psicv_terms as T
        on I.refvalue = T.code
    where T.code is null
    group by I.refvalue
    order by I.refvalue;

\copy tmp_unknown_methods to '<directory>/unknown_methods'

rollback;
