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

    -- Sequence reference database information.

    reftaxid integer not null,
    refsequence varchar not null,
    refdate varchar,
    gi integer
);
