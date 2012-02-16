-- A simple schema purely for completing interactor data.

create table refseq_proteins (
    accession varchar,
    version varchar,
    vnumber integer,
    gi integer not null,
    taxid integer,
    "sequence" varchar not null,
    primary key(gi)
);

create table refseq_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null,
    primary key(accession, dblabel, refvalue)
);

-- A mapping from protein records to nucleotide records.

create table refseq_nucleotides (
    nucleotide varchar not null,
    protein varchar not null,
    primary key(nucleotide, protein)
);

create table refseq_nucleotide_accessions (
    nucleotide varchar not null,
    shortform varchar not null,
    primary key(nucleotide)
);
