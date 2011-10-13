-- Import data into the schema.

begin;

\copy yeast_accessions from '<directory>/yeast.txt'

analyze yeast_accessions;

commit;
