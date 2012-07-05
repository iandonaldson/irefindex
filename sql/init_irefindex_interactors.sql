-- Cross-references for interactors.

create table xml_xref_all_interactors (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    reftypelabel varchar, -- retained for filtering
    dblabel varchar not null,
    refvalue varchar not null,
    originaldblabel varchar not null,
    originalrefvalue varchar not null

    -- Constraints are added after import.
);

create table xml_xref_interactors (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    reftypelabel varchar, -- retained for scoring
    dblabel varchar not null,
    refvalue varchar not null,
    originaldblabel varchar not null,
    originalrefvalue varchar not null,

    -- From xml_organisms:

    taxid integer,

    -- From xml_sequences:

    sequence varchar

    -- Constraints are added after import.
);

-- Cross-references for interactor types.

create table xml_xref_interactor_types (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, interactorid)
);

-- A mapping from accessions to reference database sequences.

create table xml_xref_sequences (

    -- Primary reference details.

    dblabel varchar not null,
    refvalue varchar not null,

    -- Link to sequence database describing how the connection was made.

    sequencelink varchar,

    -- Sequence reference database information.

    reftaxid integer,
    refsequence varchar,

    -- Sequence availability information.

    missing boolean not null default false
);

create index xml_xref_sequences_index on xml_xref_sequences(dblabel, refvalue);

-- Specific interactor sequences.

create table xml_xref_interactor_sequences (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    reftypelabel varchar,
    dblabel varchar not null,
    refvalue varchar not null,

    -- From xml_xref_interactors:

    originaldblabel varchar not null,
    originalrefvalue varchar not null,

    -- From xml_xref_sequences:

    missing boolean,

    -- From xml_organisms:

    taxid integer,

    -- From xml_sequences:

    sequence varchar,

    -- Link to sequence database describing how the connection was made.

    sequencelink varchar,

    -- Sequence reference database information.

    reftaxid integer,
    refsequence varchar

    -- Constraints are added after import.
);

-- Interactor names.

create table xml_names_interactor_names (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    nametype varchar not null,
    name varchar not null,
    primary key(source, filename, entry, interactorid, nametype, name)
);
