-- A simple schema purely for completing interactor data.

create table refseq_proteins (
    accession varchar,
    version varchar,
    vnumber integer,
    gi integer not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,
    missing boolean not null default false, -- indicates whether the protein was initially missing
    primary key(gi)
);

create table refseq_sequences (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    primary key("sequence")
);

create table refseq_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null,
    missing boolean not null default false, -- indicates whether the identifier was initially missing
    primary key(accession, dblabel, refvalue)
);

-- A mapping from protein records to nucleotide records.

create table refseq_nucleotides (
    nucleotide varchar not null,
    protein varchar not null,
    missing boolean not null default false, -- indicates whether the nucleotide was initially missing
    primary key(nucleotide, protein)
);

create table refseq_nucleotide_accessions (
    nucleotide varchar not null,
    shortform varchar not null,
    missing boolean not null default false, -- indicates whether the accession was initially missing
    primary key(nucleotide)
);
