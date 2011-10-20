create table irefindex_assignments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,

    -- Assigned sequence information.

    sequence varchar not null,
    taxid integer,

    -- Link to sequence database describing how the connection was made.

    sequencelinks varchar[],

    -- Reference type responsible for providing the sequence.

    reftype varchar not null,

    -- The nature of the assignment.
    method varchar not null,
    primary key(source, filename, entry, interactorid, sequence)
);
