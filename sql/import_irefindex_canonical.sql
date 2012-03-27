begin;

-- Make a comprehensive mapping from genes to proteins.

insert into irefindex_gene2rog
    select geneid, sequence || taxid as rogid
    from irefindex_gene2refseq
    union
    select geneid, sequence || taxid as rogid
    from irefindex_gene2uniprot;

alter table irefindex_gene2rog add primary key(geneid, rogid);
analyze irefindex_gene2rog;

-- Make an initial gene-to-gene mapping via shared ROG identifiers.

insert into irefindex_gene2related
    select distinct A.geneid, B.geneid as related
    from irefindex_gene2rog as A
    inner join irefindex_gene2rog as B
        on A.rogid = B.rogid;

analyze irefindex_gene2related;

-- Define a mapping of relevant genes using active ROG identifiers.

insert into irefindex_gene2related_active
    select distinct A.geneid, B.geneid as related
    from irefindex_gene2rog as A
    inner join irefindex_gene2rog as B
        on A.rogid = B.rogid
    inner join irefindex_rogids as C
        on A.rogid = C.rogid;

analyze irefindex_gene2related_active;

commit;
