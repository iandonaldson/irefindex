-- A simple schema purely for completing interactor data.

create table uniprot_proteins (
    uniprotid varchar not null,
    primaryaccession varchar not null,
    taxid integer not null,
    "sequence" varchar not null,
    primary key(uniprotid)
);

create table uniprot_accessions (
    uniprotid varchar not null,
    accession varchar not null,
    primary key(uniprotid, accession)
);
