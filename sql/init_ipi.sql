-- A simple schema purely for completing interactor data.

create table ipi_proteins (
    accession varchar not null,
    "sequence" varchar not null,
    primary key(accession)
);

create table ipi_identifiers (
    accession varchar not null,
    taxid integer not null,
    dblabel varchar not null,
    refvalue varchar not null,
    primary key(accession, dblabel, refvalue)
);
