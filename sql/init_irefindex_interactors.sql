-- A mapping from genes to UniProt proteins.

create table irefindex_gene2uniprot (

    -- From gene_info:

    geneid integer not null,

    -- From uniprot_proteins:

    accession varchar not null,
    sequencedate varchar,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,

    primary key(geneid, accession)
);

-- A mapping from genes to RefSeq proteins.

create table irefindex_gene2refseq (

    -- From gene_info:

    geneid integer not null,

    -- From refseq_proteins:

    accession varchar not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,

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
    refsequence varchar,
    refdate varchar

    -- Constraints are added after import.
);
