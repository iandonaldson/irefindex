begin;

-- Show the number of distinct interactors by database origin.

create temporary table tmp_all_interactors_by_database as
    select dblabel, count(distinct refvalue) as total, reftype, isidentity
    from (
        select dblabel, refvalue, reftype, case
            when reftypelabel = 'identity' then true
            else false end as isidentity
        from xml_xref_all_interactors
        where property = 'interactorType'
        ) as X
    group by dblabel, reftype, isidentity
    order by dblabel, reftype, isidentity;

\copy tmp_all_interactors_by_database to '<directory>/all_interactors_by_database'

create temporary table tmp_interactors_by_database as
    select coalesce(notfound.dblabel, found.dblabel) as dblabel,
        coalesce(notfound.total, 0) as unmatched, coalesce(found.total, 0) as matched,
        round(
            cast(
                cast(coalesce(found.total, 0) as real) / (coalesce(notfound.total, 0) + coalesce(found.total, 0)) * 100
                as numeric
                ), 2
            ) as coverage
    from (
        select dblabel, count(distinct refvalue) as total
        from xml_xref_interactor_sequences
        where refsequence is null
        group by dblabel
        ) as notfound
    full outer join (
        select dblabel, count(distinct refvalue) as total
        from xml_xref_interactor_sequences
        where refsequence is not null
        group by dblabel
        ) as found
        on notfound.dblabel = found.dblabel
    order by coalesce(notfound.dblabel, found.dblabel);

\copy tmp_interactors_by_database to '<directory>/interactors_by_database'

rollback;
