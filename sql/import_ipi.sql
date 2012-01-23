-- Import data into the schema.

begin;

\copy ipi_proteins from '<directory>/ipi_proteins.txt.seq'
\copy ipi_identifiers from '<directory>/ipi_identifiers.txt'

create index ipi_proteins_sequence on ipi_proteins(sequence);
analyze ipi_proteins;

analyze ipi_identifiers;

commit;
