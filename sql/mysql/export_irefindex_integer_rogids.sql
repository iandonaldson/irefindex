select distinct rog, concat(seguid_new, tax_cor) as rogid
from int_xref_mod
where rog_score > 0;
