-- A simple schema purely for completing interactor data.

create table pdb_proteins (
    accession varchar not null,
    gi integer not null,
    "sequence" varchar not null,
    primary key(accession, gi)
);
