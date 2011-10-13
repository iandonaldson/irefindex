-- Import data into the schema.

begin;

\copy taxonomy_names from '<directory>/names.txt'

analyze taxonomy_names;

commit;
