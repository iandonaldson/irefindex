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
    locustag varchar,
    chromosome varchar,
    primary key(geneid)
);

create table gene_maplocations (
    geneid integer not null,
    position integer not null,
    maplocation varchar not null,
    primary key(geneid, position)
);

create table gene_synonyms (
    geneid integer not null,
    position integer not null,
    "synonym" varchar not null,
    primary key(geneid, position)
);

create table gene_history (
    taxid integer not null,
    geneid integer,
    oldgeneid integer not null,
    oldsymbol varchar not null,
    primary key(oldgeneid)
);

create table gene2go (
    taxid integer not null,
    geneid integer not null,
    goid varchar not null,
    term varchar not null,
    category varchar not null,
    primary key(geneid, goid)
);
