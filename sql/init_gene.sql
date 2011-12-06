-- A simple schema purely for completing interactor data.

create table gene2refseq (
    taxid integer not null,
    geneid integer not null,
    accession varchar not null,
    primary key(geneid, accession)
);

create table gene_info (
    taxid integer not null,
    geneid integer not null,
    symbol varchar not null,
    primary key(geneid, symbol)
);
