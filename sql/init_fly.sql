-- A simple schema purely for completing interactor data.

create table fly_accessions (
    genename varchar,
    species varchar,
    uniprotid varchar not null, -- really Swiss-Prot
    accession varchar not null, -- really Swiss-Prot
    flyaccession varchar not null,
    primary key(accession, flyaccession)
);
