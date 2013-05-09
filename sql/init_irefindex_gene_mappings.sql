-- A mapping from genes to UniProt proteins.

create table irefindex_gene2uniprot (

    -- From gene_info:

    geneid integer not null,

    -- From uniprot_proteins:

    accession varchar not null,
    sequencedate varchar,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,
    source varchar not null,     -- indicates Swiss-Prot or TrEMBL origin

    primary key(geneid, accession)
);

-- A mapping from genes to RefSeq proteins.

create table irefindex_gene2refseq (

    -- From gene_info:

    geneid integer not null,

    -- From refseq_proteins:

    accession varchar not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,

    missing boolean not null default false, -- indicates whether the mapping was initially missing

    primary key(geneid, accession)
);
