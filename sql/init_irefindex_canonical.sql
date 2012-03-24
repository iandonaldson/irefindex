-- A mapping from genes to ROG identifiers.

create table irefindex_gene2rog (
    geneid integer not null,
    rogid varchar not null

    -- Primary key added later.
);

-- A mapping from genes to other genes related to the same proteins.

create table irefindex_gene2related (
    geneid integer not null,
    related integer not null,
    primary key(geneid, related)
);

-- A mapping from genes to other genes related to the same proteins starting
-- with only genes for active ROG identifiers.

create table irefindex_gene2related_active (
    geneid integer not null,
    related integer not null,
    primary key(geneid, related)
);
