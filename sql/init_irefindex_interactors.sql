create table xml_xref_sequences (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,

    -- Related information from the interaction database.

    taxid integer,
    sequence varchar,

    -- Link to sequence database describing how the connection was made.

    sequencelink varchar,

    -- Sequence reference database information.

    reftaxid integer,
    refsequence varchar,
    refdate varchar,
    gi integer
);
