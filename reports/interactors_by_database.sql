begin;

-- Show the number of distinct interactors by database origin.

create temporary table tmp_all_interactors_by_database as
    select dblabel, count(distinct refvalue) as total, reftype, isidentity
    from (
        select dblabel, refvalue, reftype, case
            when reftypelabel = 'identity' then true
            else false end as isidentity
        from xml_xref_all_interactors
        ) as X
    group by dblabel, reftype, isidentity
    order by dblabel, reftype, isidentity;

\copy tmp_all_interactors_by_database to '<directory>/all_interactors_by_database'

create temporary table tmp_interactors_by_database as
    select dblabel, count(distinct refvalue) as total, havesequence
    from (
        select dblabel, refvalue, case
            when count(refsequence) = 0 then false
            else true end as havesequence
        from xml_xref_interactor_sequences
        group by dblabel, refvalue
        ) as X
    group by dblabel, havesequence
    order by dblabel, havesequence;

\copy tmp_interactors_by_database to '<directory>/interactors_by_database'

rollback;
