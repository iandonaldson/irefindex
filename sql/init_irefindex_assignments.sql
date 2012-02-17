-- Ambiguity of interactors defined in terms of matching sequences.

create table irefindex_ambiguity (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    refsequences integer not null,
    primary key(source, filename, entry, interactorid, reftype)
);

-- Assignments of sequences to interactors.

create table irefindex_assignments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    originaltaxid integer,

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

-- Unassigned interactors.

create table irefindex_unassigned (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    taxid integer,
    sequence varchar,
    refsequences integer not null,
    primary key(source, filename, entry, interactorid)
);

-- Assignments of ROG identifiers to interactors based on the above sequence
-- assignment.

create table irefindex_rogids (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    rogid varchar not null,
    primary key(source, filename, entry, interactorid)
);
