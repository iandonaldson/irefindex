create table irefindex_ambiguity (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    refsequences integer not null,
    primary key(source, filename, entry, interactorid, reftype)
);

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

    -- Identifier information.

    identifiers varchar[][],

    -- The nature of the assignment.

    method varchar not null,
    primary key(source, filename, entry, interactorid, sequence)
);

create table irefindex_unassigned (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    sequence varchar,
    refsequences integer not null,
    primary key(source, filename, entry, interactorid)
);
