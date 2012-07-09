create table dig_diseases (
    digid integer not null,
    name varchar not null,
    diseaseomimid integer,
    diseasetag integer,
    geneomimid integer not null,
    locus varchar not null,
    primary key(digid)
);

create table dig_genes (
    digid integer not null,
    symbol varchar not null,
    primary key(digid, symbol)
);
