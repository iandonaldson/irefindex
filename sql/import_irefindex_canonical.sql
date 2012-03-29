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

-- Define a mapping of relevant genes using known sequences from interaction
-- records. Since this activity may be performed before assignment, the ROG
-- identifiers may not be available.

create temporary table tmp_rogids as
    select distinct refsequence || reftaxid as rogid
    from xml_xref_sequences
    where refsequence is not null and reftaxid is not null
    union
    select distinct sequence || taxid as rogid
    from xml_xref_interactors
    where sequence is not null and taxid is not null;

analyze tmp_rogids;

insert into irefindex_gene2related_active
    select distinct A.geneid, B.geneid as related
    from irefindex_gene2rog as A
    inner join irefindex_gene2rog as B
        on A.rogid = B.rogid
    inner join tmp_rogids as C
        on A.rogid = C.rogid;

analyze irefindex_gene2related_active;

commit;
