begin;

create temporary table tmp_protein_identifier_mapping as
    select
        coalesce(X.dblabel, X3.dblabel) as dblabel,
        coalesce(X.refvalue, X3.refvalue) as refvalue,
        case when X.dblabel = 'refseq' then coalesce(cast(X2.refvalue as integer), -1) else -1 end as geneid,
        I.rog,
        I.rogid,
        CI.rog as crog,
        CI.rogid as crogid

    -- Limit the mapping to active interactors.
    -- The irefindex_rogids table includes source interactor details, but the
    -- canonical table has one record per interactor.

    from irefindex_rogids_canonical as R

    -- Obtain integer identifiers.

    inner join irefindex_rog2rogid as I
        on R.rogid = I.rogid

    -- Obtain canonical information.

    inner join irefindex_rogids_canonical as C
        on R.rogid = C.rogid
    inner join irefindex_rog2rogid as CI
        on C.rogid = CI.rogid

    -- RefSeq and UniProt information, if available.

    left outer join irefindex_rogid_identifiers as X
        on R.rogid = X.rogid
        and X.dblabel in ('refseq', 'uniprotkb')

    -- Gene information for RefSeq records.

    left outer join irefindex_rogid_identifiers as X2
        on R.rogid = X2.rogid
        and X2.dblabel = 'entrezgene/locuslink'

    -- Other identifiers.

    left outer join irefindex_rogid_identifiers as X3
        on R.rogid = X3.rogid
        and X3.dblabel not in ('refseq', 'uniprotkb', 'entrezgene/locuslink')

    -- Choose either RefSeq/UniProt identifiers or other identifiers, but not both.

    where X.dblabel is not null and X3.dblabel is null
        or X.dblabel is null and X3.dblabel is not null;

\copy tmp_protein_identifier_mapping to '<directory>/mappings.txt'

rollback;
