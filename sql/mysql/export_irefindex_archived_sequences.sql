select distinct seguid, sequence, D.name
from seguid2sequence as S
inner join int_xref_mod as X
    on S.seguid = X.seguid_new
inner join int_db as D
    on X.source = D.id
where S.seguid <> '0';
