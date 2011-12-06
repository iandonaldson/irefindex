-- A simple schema purely for completing interactor data.

create table uniprot_proteins (
    uniprotid varchar not null,
    primaryaccession varchar not null,
    sequencedate varchar, -- not supplied by FASTA
    taxid integer,        -- not supplied by FASTA
    "sequence" varchar not null,
    primary key(uniprotid, primaryaccession, sequence)
);

create table uniprot_accessions (
    uniprotid varchar not null,
    accession varchar not null,
    primary key(uniprotid, accession)
);

create table uniprot_identifiers (
    uniprotid varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null,
    primary key(uniprotid, dblabel, refvalue)
);

create table uniprot_gene_names (
    uniprotid varchar not null,
    genename varchar not null,
    position integer not null,
    primary key(uniprotid, genename)
);

create table uniprot_isoforms (
    uniprotid varchar not null,
    accession varchar not null,
    isoform varchar not null,
    primary key(uniprotid, accession, isoform)
);
