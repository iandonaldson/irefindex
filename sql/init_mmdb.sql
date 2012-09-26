-- A simple schema purely for completing interactor data.

create table mmdb_pdb_accessions (
    accession varchar not null,
    chain varchar not null,
    gi integer not null,
    taxid integer not null,
    primary key(accession, chain, gi)
);
