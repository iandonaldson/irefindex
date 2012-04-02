begin;

create temporary table tmp_unknown_types as
    select I.refvalue, count(*) as total
    from xml_xref_interaction_types as I
    left outer join psicv_terms as T
        on I.refvalue = T.code
    where T.code is null
    group by I.refvalue
    order by I.refvalue;

\copy tmp_unknown_types to '<directory>/unknown_interaction_types'

rollback;
