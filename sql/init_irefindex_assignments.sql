-- Ambiguity of interactors defined in terms of matching sequences.

create table irefindex_ambiguity (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    refsequences integer not null,
    reftaxids integer not null,
    primary key(source, filename, entry, interactorid, reftype)
);

-- Assignments of sequences to interactors.
-- There may be more than one record per interactor, but no more than one
-- distinct sequence per interactor. The redundancy is provided by the
-- sequencelink, dblabel and refvalue columns.

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

    sequencelink varchar,

    -- Reference type responsible for providing the sequence.

    reftype varchar not null,
    reftypelabel varchar,

    -- Identifier information.

    dblabel varchar not null,
    refvalue varchar not null,

    -- Labelling and availability information.

    dblabelchanged boolean not null,
    missing boolean,

    -- The nature of the assignment.

    method varchar not null,

    -- Since various columns can be null, a unique constraint is employed.
    -- When populating this table, distinct selections should ensure that null
    -- values do not cause unnecessary record duplication.

    unique(source, filename, entry, interactorid, sequence, sequencelink, dblabel, refvalue)
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

-- Preferred assignments.
-- There may be many assignment records per interactor since different paths to
-- sequences may have been taken using the available identifiers. The preferred
-- table retains only one path per interactor, choosing a particular identifier
-- (and thus interpretation).

create table irefindex_assignments_preferred (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,

    -- Specific assignment details.

    sequencelink varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, interactorid)
);

-- Assignment scores.

create table irefindex_assignment_scores (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    score varchar not null,
    primary key(source, filename, entry, interactorid, score)
);

-- Assignments of ROG identifiers to interactors based on the above sequence
-- assignment.

create table irefindex_rogids (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    rogid varchar not null, -- collate "C" would require PostgreSQL 9.1
    taxid integer not null,
    method varchar not null,
    primary key(source, filename, entry, interactorid)
);

-- A mapping from ROG identifiers to all database identifiers referring to that
-- object.

create table irefindex_rogid_identifiers (
    rogid varchar not null, -- collate "C" would require PostgreSQL 9.1
    dblabel varchar not null,
    refvalue varchar not null,
    primary key(rogid, dblabel, refvalue)
);

-- Complete interactions where all interactors could be assigned a ROG
-- identifier if complete is true.

create table irefindex_interactions_complete (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    complete boolean not null,
    primary key(source, filename, entry, interactionid)
);
