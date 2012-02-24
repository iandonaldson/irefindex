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
    property varchar not null

    -- Constraints are added after import.
);

create table xml_xref_interactors (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    reftype varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,

    -- From xml_organisms:

    taxid integer,

    -- From xml_sequences:

    sequence varchar

    -- Constraints are added after import.
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
    refdate varchar

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
    dblabel varchar not null,
    refvalue varchar not null,

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
