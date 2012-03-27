begin;

insert into irefindex_rgg_genes
    select min(related) as rggid, geneid
    from irefindex_gene2related_active
    group by geneid;

analyze irefindex_rgg_genes;

insert into irefindex_rgg_rogids
    select distinct rggid, rogid
    from irefindex_rgg_genes as G
    inner join irefindex_gene2rog as R
        on G.geneid = R.geneid;

analyze irefindex_rgg_rogids;

-- Use the length and primary UniProt accession availability, selecting a RefSeq
-- accession otherwise.

insert into irefindex_rgg_rogids_canonical
    select R.rggid, coalesce(min(G1.sequence || G1.taxid), min(G2.sequence || G2.taxid)) as rogid
    from irefindex_rgg_rogids as R
    left outer join (
        select rggid, max(length) as length
        from irefindex_rgg_rogids as R
        inner join irefindex_gene2uniprot as G
            on R.rogid = G.sequence || G.taxid
        group by rggid
        ) as X1
        on R.rggid = X1.rggid
    left outer join irefindex_gene2uniprot as G1
        on X1.length = G1.length
        and R.rogid = G1.sequence || G1.taxid
    left outer join (
        select rggid, max(length) as length
        from irefindex_rgg_rogids as R
        inner join irefindex_gene2refseq as G
            on R.rogid = G.sequence || G.taxid
        group by rggid
        ) as X2
        on R.rggid = X2.rggid
    left outer join irefindex_gene2refseq as G2
        on X2.length = G2.length
        and R.rogid = G2.sequence || G2.taxid
    group by R.rggid;

analyze irefindex_rgg_rogids_canonical;

-- Make a mapping from ROG identifiers to canonical ROG identifiers.

insert into irefindex_rogids_canonical
    select distinct R.rogid, C.rogid
    from irefindex_rgg_rogids as R
    inner join irefindex_rgg_rogids_canonical as C
        on R.rggid = C.rggid;

analyze irefindex_rogids_canonical;

-- Canonical RIG identifiers are produced once RIG identifiers are available.

commit;
