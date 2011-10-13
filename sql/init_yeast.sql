-- A simple schema purely for completing interactor data.

create table yeast_accessions (
    genename varchar not null,
    orderedlocus varchar,
    accession varchar not null, -- really Swiss-Prot
    uniprotid varchar not null, -- really Swiss-Prot
    sgdxref varchar not null,
    sequencelength integer not null,
    structure3d boolean not null,
    chromosome varchar not null,
    primary key(genename)
);
