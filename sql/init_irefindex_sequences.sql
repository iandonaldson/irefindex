-- A mapping from accessions to reference database sequences.

create table irefindex_sequences (

    -- Primary reference details.

    dblabel varchar not null,
    refvalue varchar not null,

    -- Sequence reference database information.

    reftaxid integer,
    refsequence varchar,
    refdate varchar

    -- Constraints are added after import.
);
