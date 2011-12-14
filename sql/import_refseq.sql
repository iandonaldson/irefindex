-- Import data into the schema.

begin;

\copy refseq_proteins from '<directory>/refseq_proteins.txt.seq'

create index refseq_proteins_version on refseq_proteins(version);
create index refseq_proteins_sequence on refseq_proteins(sequence);
analyze refseq_proteins;

commit;
