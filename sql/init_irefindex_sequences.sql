-- A mapping from accessions to reference database sequences.

create table irefindex_sequences (

    -- Identifier details.

    dblabel varchar not null,
    refvalue varchar not null,

    -- Sequence reference database information.

    reftaxid integer,
    refsequence varchar not null,
    refdate varchar

    -- Constraints are added after import.
);

-- A collection of ROG identifiers for all taxonomy-qualified sequences.

create table irefindex_sequence_rogids (
    rogid varchar not null,
    primary key(rogid)
);

-- Actual sequences together with their digests.

create table irefindex_sequences_original (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    dblabel varchar not null,               -- the origin of the sequence record
    primary key("sequence", dblabel)
);
