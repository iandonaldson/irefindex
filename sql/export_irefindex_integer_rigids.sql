begin;

create temporary table tmp_rigids as
    select rig, rigid
    from irefindex_rig2rigid;

\copy tmp_rigids to '<directory>/rig2rigid'

rollback;
