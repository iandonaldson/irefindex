-- A simple schema purely for completing interactor data.

create table refseq_proteins (
    accession varchar not null,
    taxid integer not null,
    "sequence" varchar not null,
    primary key(accession)
);
