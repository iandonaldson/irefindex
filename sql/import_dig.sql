begin;

\copy dig_diseases from '<directory>/dig.txt'
\copy dig_genes from '<directory>/dig_genes.txt'

analyze dig_diseases;
analyze dig_genes;

commit;
