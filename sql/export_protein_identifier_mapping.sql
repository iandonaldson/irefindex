begin;

create temporary table tmp_protein_identifier_mapping as
    select X.dblabel, X.refvalue,
        case when X.dblabel = 'refseq' then cast(X2.refvalue as integer) else -1 end as geneid,
        I.rog, I.rogid, CI.rog as crog, CI.rogid as crogid
    from irefindex_rog2rogid as I
    inner join irefindex_rogids_canonical as C
        on I.rogid = C.rogid
    inner join irefindex_rog2rogid as CI
        on C.rogid = CI.rogid
    inner join irefindex_rogid_identifiers as X
        on I.rogid = X.rogid
        and X.dblabel in ('refseq', 'uniprotkb')
    left outer join irefindex_rogid_identifiers as X2
        on I.rogid = X2.rogid
        and X2.dblabel = 'entrezgene/locuslink';

\copy tmp_protein_identifier_mapping to '<directory>/mappings.txt'

rollback;
