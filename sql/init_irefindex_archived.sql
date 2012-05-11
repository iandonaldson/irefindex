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
