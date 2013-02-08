-- A simple schema purely for completing interactor data.

create table ipi_proteins (
    accession varchar not null,
    "sequence" varchar not null,
    length integer not null,
    primary key(accession)
);

create table ipi_sequences (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    primary key("sequence")
);

create table ipi_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    primary key(accession, dblabel, refvalue)
);

create table ipi_accessions (
    accession varchar not null,
    shortform varchar not null,
    primary key(accession)
);
