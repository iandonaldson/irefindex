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
