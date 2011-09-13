-- Import data into the schema.

begin;

\copy pdb_proteins from '<directory>/pdbaa_proteins.txt.seq'

create index pdb_proteins_sequence on pdb_proteins(sequence);
analyze pdb_proteins;

commit;
