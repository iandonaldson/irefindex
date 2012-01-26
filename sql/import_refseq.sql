-- Import data into the schema.

begin;

\copy refseq_proteins from '<directory>/refseq_proteins.txt.seq'
\copy refseq_identifiers from '<directory>/refseq_identifiers.txt'
\copy refseq_nucleotides from '<directory>/refseq_nucleotides.txt'

create index refseq_proteins_version on refseq_proteins(version);
create index refseq_proteins_sequence on refseq_proteins(sequence);
analyze refseq_proteins;

analyze refseq_identifiers;

analyze refseq_nucleotides;

insert into refseq_nucleotide_accessions
    select distinct nucleotide, substring(nucleotide from '[^.]*') as shortform
    from refseq_nucleotides;

create index refseq_nucleotide_accessions_shortform on refseq_nucleotide_accessions(shortform);
analyze refseq_nucleotide_accessions;

commit;
