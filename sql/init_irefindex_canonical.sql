-- A mapping from genes to ROG identifiers.

create table gene2rog (
    geneid integer not null,
    rogid varchar not null,
    primary key(geneid, rogid)
);

-- A mapping from genes to other genes related to the same proteins.

create table gene2related (
    geneid integer not null,
    related integer not null,
    primary key(geneid, related)
);
