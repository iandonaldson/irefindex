-- A simple schema purely for completing interactor data.

create table genpept_proteins (
    accession varchar not null,
    db varchar not null,
    gi integer not null,
    "sequence" varchar not null,
    primary key(accession, db)
);

create table genpept_accessions (
    accession varchar not null,
    shortform varchar not null,
    primary key(accession)
);
