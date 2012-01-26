-- Import data into the schema.

begin;

\copy gene2refseq from '<directory>/gene2refseq.txt'
\copy gene_info from '<directory>/gene_info.txt'
\copy gene_history from '<directory>/gene_history.txt'

analyze gene2refseq;
analyze gene_info;
analyze gene_history;

commit;
