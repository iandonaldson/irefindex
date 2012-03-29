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

-- A mapping from redundant gene group (RGG) identifiers to genes.

create table irefindex_rgg_genes (
    rggid integer not null,
    geneid integer not null,
    primary key(rggid, geneid)
);

-- ROG identifiers for RGGs.

create table irefindex_rgg_rogids (
    rggid integer not null,
    rogid varchar not null,
    primary key(rggid, rogid)
);

-- Canonical ROG identifiers for RGGs.

create table irefindex_rgg_rogids_canonical (
    rggid integer not null,
    rogid varchar not null,
    primary key(rggid)
);

-- Canonical ROG identifiers for ROGs.
-- This complete mapping is populated in the assignment activity.

create table irefindex_rogids_canonical (
    rogid varchar not null,
    crogid varchar not null,
    primary key(rogid)
);

-- Canonical RIG identifiers for RIGs.

create table irefindex_rigids_canonical (
    rigid varchar not null,
    crigid varchar not null,
    primary key(rigid)
);
