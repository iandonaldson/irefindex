-- A simple schema purely for completing interactor data.

create table pdb_proteins (
    accession varchar not null,
    chain varchar not null,
    gi integer not null,
    "sequence" varchar not null,
    length integer not null,
    primary key(accession, chain)
);

create table pdb_sequences (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    primary key("sequence")
);
