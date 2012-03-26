-- Import data into the schema.

begin;

create temporary table tmp_refseq_proteins (
    accession varchar,
    version varchar,
    gi integer not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null
);

\copy tmp_refseq_proteins from '<directory>/refseq_proteins.txt.seq'
\copy refseq_identifiers from '<directory>/refseq_identifiers.txt'
\copy refseq_nucleotides from '<directory>/refseq_nucleotides.txt'

insert into refseq_proteins
    select accession, version,
        case when position('.' in version) <> 0 then
            cast(substring(version from position('.' in version) + 1) as integer)
        else null end as vnumber,
        gi, taxid, "sequence", length, false as missing
    from tmp_refseq_proteins;

create index refseq_proteins_accession on refseq_proteins(accession);
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
