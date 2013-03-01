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

-- A mapping from genes to other genes related to the same proteins covering
-- only new mapping information.

create table irefindex_gene2related_active (
    geneid integer not null,
    related integer not null,
    primary key(geneid, related)
);

-- A comprehensive mapping from genes to other genes related to the same
-- proteins.

create table irefindex_gene2related_known (
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

create table irefindex_sequence_rogids_canonical (
    rogid varchar not null,
    crogid varchar not null,
    primary key(rogid)
);

-- (The complete active mapping is defined and populated in the assignment activity.)

-- Canonical RIG identifiers for RIGs.

create table irefindex_rigids_canonical (
    rigid varchar not null,
    crigid varchar not null,
    primary key(rigid)
);

-- A table providing a mapping from canonical RIG identifiers to the canonical ROG
-- identifiers used in their construction, without referencing individual
-- interaction records.

create table irefindex_distinct_interactions_canonical (
    rigid varchar not null,
    rogid varchar not null
);
