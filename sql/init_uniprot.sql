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
