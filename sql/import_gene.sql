-- Import data into the schema.

begin;

\copy gene2refseq from '<directory>/gene2refseq.txt'

analyze gene2refseq;

commit;
