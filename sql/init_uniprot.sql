-- A simple schema purely for completing interactor data.

-- Accessions in the proteins table are primary accessions from the main
-- UniProt data files and isoforms from the FASTA files.

create table uniprot_proteins (
    uniprotid varchar not null,
    accession varchar not null,
    sequencedate varchar,           -- not supplied by FASTA
    taxid integer,                  -- not supplied by FASTA
    mw integer,                     -- not supplied by FASTA
    "sequence" varchar not null,
    length integer not null,
    primary key(accession)
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
    isoform varchar not null,
    parent varchar not null,
    primary key(isoform)
);
