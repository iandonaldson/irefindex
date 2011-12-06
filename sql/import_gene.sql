-- Import data into the schema.

begin;

\copy gene2refseq from '<directory>/gene2refseq.txt'
\copy gene_info from '<directory>/gene_info.txt'

analyze gene2refseq;
analyze gene_info;

commit;
