-- Import data into the schema.

begin;

\copy uniprot_proteins from '<directory>/uniprot_sprot_proteins.txt.seq'
\copy uniprot_proteins from '<directory>/uniprot_trembl_proteins.txt.seq'
\copy uniprot_accessions from '<directory>/uniprot_sprot_accessions.txt'
\copy uniprot_accessions from '<directory>/uniprot_trembl_accessions.txt'
\copy uniprot_identifiers from '<directory>/uniprot_sprot_identifiers.txt'
\copy uniprot_identifiers from '<directory>/uniprot_trembl_identifiers.txt'
\copy uniprot_gene_names from '<directory>/uniprot_sprot_gene_names.txt'
\copy uniprot_gene_names from '<directory>/uniprot_trembl_gene_names.txt'

create index uniprot_accessions_accession on uniprot_accessions(accession);
analyze uniprot_accessions;

create index uniprot_proteins_sequence on uniprot_proteins(sequence);
analyze uniprot_proteins;

create index uniprot_proteins_index on uniprot_proteins(uniprotid);
analyze uniprot_proteins;

create index uniprot_gene_names_genename on uniprot_gene_names(genename);
analyze uniprot_gene_names;

create temporary table tmp_uniprot_proteins (
    uniprotid varchar not null,
    accession varchar not null,
    sequencedate varchar,
    taxid integer,
    sequence varchar not null,
    primary key(accession)
);

-- Add FASTA data.

\copy tmp_uniprot_proteins from '<directory>/uniprot_sprot_varsplic_proteins.txt.seq'

analyze tmp_uniprot_proteins;

-- Merge with the imported proteins.

insert into uniprot_proteins
    select A.uniprotid, A.accession, A.sequencedate, A.taxid, A.sequence
    from tmp_uniprot_proteins as A
    left outer join uniprot_proteins as B
        on A.accession = B.accession
    where B.uniprotid is null;

analyze uniprot_proteins;

-- Add missing taxid information.

update uniprot_proteins as P
    set taxid = (
        select min(Q.taxid)
        from uniprot_proteins as Q
        where Q.uniprotid = P.uniprotid
            and Q.taxid is not null
        )
    where taxid is null;

-- Add the isoform mapping.

insert into uniprot_isoforms
    select uniprotid, accession, substring(accession from 1 for 6) as parent
    from uniprot_proteins
    where length(accession) > 6;

analyze uniprot_isoforms;

commit;
