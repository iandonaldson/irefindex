select distinct dblabel, refvalue, taxid, sequence
from (
    select D.name as dblabel, acc_mapped as refvalue, seguid_new as sequence, taxid_mapped as taxid
    from int_xref_mod as X
    inner join int_db as D
        on db_mapped = D.id
    where seguid_new <> '0'
    ) as X;
