-- Import data into the schema.

begin;

\copy uniprot_proteins from '<directory>/uniprot_sprot_proteins.txt.seq'
\copy uniprot_proteins from '<directory>/uniprot_trembl_proteins.txt.seq'
\copy uniprot_accessions from '<directory>/uniprot_sprot_accessions.txt'
\copy uniprot_accessions from '<directory>/uniprot_trembl_accessions.txt'

create index uniprot_accessions_accession on uniprot_accessions(accession);
analyze uniprot_accessions;

create index uniprot_proteins_sequence on uniprot_proteins(sequence);
analyze uniprot_proteins;

create temporary table tmp_uniprot_proteins (
    uniprotid varchar not null,
    primaryaccession varchar not null,
    sequencedate varchar,
    taxid integer,
    sequence varchar not null,
    primary key(uniprotid, primaryaccession, sequence)
);

-- Add FASTA data.

\copy tmp_uniprot_proteins from '<directory>/uniprot_sprot_varsplic_proteins.txt.seq'

analyze tmp_uniprot_proteins;

-- Remove trailing "-n" from accessions.

insert into uniprot_proteins
    select A.uniprotid, A.primaryaccession, A.sequencedate, A.taxid, A.sequence
    from (
        select uniprotid,
            case when length(primaryaccession) > 6 then substring(primaryaccession from 1 for 6)
            else primaryaccession
            end as primaryaccession,
            sequencedate, taxid, sequence
        from tmp_uniprot_proteins
        ) as A
    left outer join uniprot_proteins as B
        on (A.uniprotid, A.primaryaccession, A.sequence) =
            (B.uniprotid, B.primaryaccession, B.sequence)
    where B.uniprotid is null;

commit;
