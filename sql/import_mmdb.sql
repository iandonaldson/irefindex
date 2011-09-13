-- Import data into the schema.

begin;

\copy mmdb_pdb_accessions from '<directory>/table.txt'

analyze mmdb_pdb_accessions;

commit;
