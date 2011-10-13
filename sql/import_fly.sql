-- Import data into the schema.

begin;

\copy fly_accessions from '<directory>/fly.txt'

analyze fly_accessions;

commit;
