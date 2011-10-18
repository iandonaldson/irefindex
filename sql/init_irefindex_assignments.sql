create table irefindex_assignments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,

    -- Assigned sequence information.

    sequence varchar not null,
    taxid integer,

    -- Link to sequence database describing how the connection was made.

    sequencelink varchar,
    primary key(source, filename, entry, interactorid, sequence)
);
