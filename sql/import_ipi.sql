-- Import data into the schema.

begin;

\copy ipi_proteins from '<directory>/ipi_proteins.txt.seq'
\copy ipi_identifiers from '<directory>/ipi_identifiers.txt'

insert into ipi_accessions
    select accession, substring(accession from '[^.]*') as shortform
    from ipi_proteins;

create index ipi_proteins_sequence on ipi_proteins(sequence);
analyze ipi_proteins;

create index ipi_accessions_shortform on ipi_accessions(shortform);
analyze ipi_accessions;

analyze ipi_identifiers;

commit;
