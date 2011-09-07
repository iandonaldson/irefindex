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

commit;
