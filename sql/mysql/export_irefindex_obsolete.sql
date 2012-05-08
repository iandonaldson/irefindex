select distinct dblabel, refvalue, sequence, taxid
from (
    select case when db like 'uniprot%' or db = 'Swiss-Prot' then 'uniprotkb'
                else lower(db)
           end as dblabel,
           acc as refvalue,
           seguid as sequence,
           taxid
    from seguid_remv
    ) as X;
