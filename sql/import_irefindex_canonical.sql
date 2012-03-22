begin;

insert into gene2rog

    -- Direct correspondence between genes and ROGs.

    select distinct cast(refvalue as integer) as geneid, rogid
    from xml_xref_rogid_identifiers
    where dblabel = 'entrezgene'
    union

    -- Correspondence via RefSeq accessions and versions.

    select distinct geneid, rogid
    from gene2refseq as G
    inner join xml_xref_rogid_identifiers as R
        on accession = R.refvalue
        and R.dblabel = 'refseq'
    union

    -- Correspondence via RefSeq versions converted to accessions.

    select distinct geneid, R.rogid
    from gene2refseq as G
    inner join xml_xref_rogid_identifiers as R
        on position('.' in accession) <> 0
        and substring(accession from 1 for position('.' in accession) - 1) = R.refvalue
        and R.dblabel = 'refseq'

    -- Exclude existing matches.
    -- NOTE: Arguably unnecessary since the gene-to-ROG mapping will be distinct.

    left outer join xml_xref_rogid_identifiers as R2
        on accession = R2.refvalue
        and R2.dblabel = 'refseq'
    where R2.refvalue is null
    union

    -- Correspondence via UniProt accessions.

    select distinct geneid, rogid
    from gene2uniprot as G
    inner join xml_xref_rogid_identifiers as R
        on accession = R.refvalue
        and R.dblabel = 'uniprotkb'
    union

    -- Correspondence via UniProt isoforms converted to accessions.

    select distinct geneid, R.rogid
    from gene2uniprot as G
    inner join xml_xref_rogid_identifiers as R
        on position('-' in accession) <> 0
        and substring(accession from 1 for position('-' in accession) - 1) = R.refvalue
        and R.dblabel = 'uniprotkb'

    -- Exclude existing matches.
    -- NOTE: Arguably unnecessary since the gene-to-ROG mapping will be distinct.

    left outer join xml_xref_rogid_identifiers as R2
        on accession = R2.refvalue
        and R2.dblabel = 'uniprotkb'
    where R2.refvalue is null;

analyze gene2rog;

-- Make an initial gene-to-gene mapping via shared ROG identifiers.

insert into gene2related
    select distinct A.geneid, B.geneid as related
    from gene2rog as A
    inner join gene2rog as B
        on A.rogid = B.rogid;

analyze gene2related;

commit;
