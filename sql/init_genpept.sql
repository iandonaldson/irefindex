-- A simple schema purely for completing interactor data.

create table genpept_proteins (
    accession varchar not null,
    db varchar not null,
    gi integer not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,
    primary key(accession, db)
);

create table genpept_sequences (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    primary key("sequence")
);

create table genpept_accessions (
    accession varchar not null,
    shortform varchar not null,
    primary key(accession)
);
