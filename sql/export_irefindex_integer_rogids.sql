begin;

create temporary table tmp_rogids as
    select rog, rogid
    from irefindex_rog2rogid;

\copy tmp_rogids to '<directory>/rog2rogid'

rollback;
