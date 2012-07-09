create table dig_diseases (
    title varchar not null,
    locus varchar not null,
    diseaseomimid integer not null,
    diseasetag varchar not null,
    geneid integer not null,
    digid integer not null,
    name varchar not null,
    geneomimid integer not null
);

create table dig_genes (
    symbol varchar not null,
    digid integer not null,
    primary key(digid, symbol)
);
