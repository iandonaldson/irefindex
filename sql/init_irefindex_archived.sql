-- Archived sequences.

create table irefindex_sequences_archived (

    -- Identifier details.

    dblabel varchar not null,
    refvalue varchar not null,

    -- Sequence reference database information.

    reftaxid integer not null,
    refsequence varchar not null

    -- Constraints are added after import.
);

-- Actual sequences together with their digests.

create table irefindex_sequences_archived_original (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    dblabel varchar not null,               -- the origin of the sequence record
    primary key("sequence", dblabel)
);
