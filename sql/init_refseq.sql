-- A simple schema purely for completing interactor data.

create table refseq_proteins (
    accession varchar not null,
    version varchar not null,
    gi integer not null,
    taxid integer not null,
    "sequence" varchar not null,
    primary key(accession)
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
