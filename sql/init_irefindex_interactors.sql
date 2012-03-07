-- A mapping from genes to UniProt proteins.

create table gene2uniprot (

    -- From gene_info:

    geneid integer not null,

    -- From uniprot_proteins:

    accession varchar not null,
    sequencedate varchar,
    taxid integer,
    "sequence" varchar not null,

    primary key(geneid, accession)
);

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
    dblabelchanged boolean not null

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
    dblabelchanged boolean not null,

    -- From xml_organisms:

    taxid integer,

    -- From xml_sequences:

    sequence varchar

    -- Constraints are added after import.
);

-- Cross-references for interactor types.

create table xml_xref_all_interactor_types (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    reftypelabel varchar, -- retained for filtering
    dblabel varchar not null,
    refvalue varchar not null

    -- Constraints are added after import.
);

create table xml_xref_interactor_types (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, interactorid)
);

-- Uniform interactions (where all interactors have the same type).

create table xml_interactions_uniform (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    refvalue varchar, -- the value given as the PSI-MI interactor type
    primary key(source, filename, entry, interactionid)
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
    refdate varchar,

    -- Sequence availability information.

    missing boolean not null default false

    -- Constraints are added after import.
);

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

    dblabelchanged boolean not null,

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
    refsequence varchar,
    refdate varchar

    -- Constraints are added after import.
);
