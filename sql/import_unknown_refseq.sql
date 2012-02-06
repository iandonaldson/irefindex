-- Import data into the schema.

begin;

create temporary table tmp_refseq_proteins (
    accession varchar not null,
    version varchar not null,
    gi integer not null,
    taxid integer not null,
    "sequence" varchar not null,
    primary key(accession)
);

create temporary table tmp_refseq_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null,
    primary key(accession, dblabel, refvalue)
);

-- A mapping from protein records to nucleotide records.

create temporary table tmp_refseq_nucleotides (
    nucleotide varchar not null,
    protein varchar not null,
    primary key(nucleotide, protein)
);

create temporary table tmp_refseq_nucleotide_accessions (
    nucleotide varchar not null,
    shortform varchar not null,
    primary key(nucleotide)
);

\copy tmp_refseq_proteins from '<directory>/refseq_proteins.txt.seq'
\copy tmp_refseq_identifiers from '<directory>/refseq_identifiers.txt'
\copy tmp_refseq_nucleotides from '<directory>/refseq_nucleotides.txt'

insert into tmp_refseq_nucleotide_accessions
    select distinct T.nucleotide, substring(T.nucleotide from '[^.]*') as shortform
    from tmp_refseq_nucleotides as T;

analyze tmp_refseq_proteins;
analyze tmp_refseq_identifiers;
analyze tmp_refseq_nucleotides;
analyze tmp_refseq_nucleotide_accessions;

-- Augment the existing tables.

insert into refseq_proteins
    select T.*
    from tmp_refseq_proteins as T
    left outer join refseq_proteins as P
        on T.accession = P.accession
    where P.accession is null;

analyze refseq_proteins;

insert into refseq_identifiers
    select T.*
    from tmp_refseq_identifiers as T
    left outer join refseq_identifiers as I
        on T.accession = I.accession
        and T.dblabel = I.dblabel
        and T.refvalue = I.refvalue
    where I.accession is null;

analyze refseq_identifiers;

insert into refseq_nucleotides
    select T.*
    from tmp_refseq_nucleotides as T
    left outer join refseq_nucleotides as N
        on T.nucleotide = N.nucleotide
        and T.protein = N.protein
    where N.nucleotide is null;

analyze refseq_nucleotides;

insert into refseq_nucleotide_accessions
    select T.*
    from tmp_refseq_nucleotide_accessions as T
    left outer join refseq_nucleotide_accessions as A
        on T.nucleotide = A.nucleotide
    where A.nucleotide is null;

analyze refseq_nucleotide_accessions;

-- Augment the interactor tables.

-- Partition RefSeq accession matches.

-- RefSeq accession matches with and without versioning.

create temporary table tmp_refseq as

    -- RefSeq accession matches.

    select distinct X.dblabel, X.refvalue, 'refseq' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join tmp_refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.accession
    union all

    -- RefSeq accession matches using versioning.

    select distinct X.dblabel, X.refvalue, 'refseq' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join tmp_refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.version;

create index tmp_refseq_refvalue on tmp_refseq(refvalue);
analyze tmp_refseq;

-- RefSeq accession matches via nucleotide accessions.

create temporary table tmp_refseq_nucleotide as
    select distinct X.dblabel, X.refvalue, 'refseq/nucleotide' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join tmp_refseq_nucleotides as N
        on X.refvalue = N.nucleotide
    inner join tmp_refseq_proteins as P
        on N.protein = P.accession

    -- Exclude previous matches.

    left outer join tmp_refseq as P2
        on X.refvalue = P2.refvalue
    where X.dblabel = 'refseq'
        and P2.refvalue is null;

create index tmp_refseq_nucleotide_refvalue on tmp_refseq_nucleotide(refvalue);
analyze tmp_refseq_nucleotide;

create temporary table tmp_refseq_nucleotide_shortform as
    select distinct X.dblabel, X.refvalue, 'refseq/nucleotide-shortform' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join tmp_refseq_nucleotide_accessions as A
        on X.refvalue = A.shortform
    inner join tmp_refseq_nucleotides as N
        on A.nucleotide = N.nucleotide
    inner join tmp_refseq_proteins as P
        on N.protein = P.accession

    -- Exclude previous matches.

    left outer join tmp_refseq as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_refseq_nucleotide as P3
        on X.refvalue = P3.refvalue
    where X.dblabel = 'refseq'
        and P2.refvalue is null
        and P3.refvalue is null;

create index tmp_refseq_nucleotide_shortform_refvalue on tmp_refseq_nucleotide_shortform(refvalue);
analyze tmp_refseq_nucleotide_shortform;

-- RefSeq accession matches via Entrez Gene.

create temporary table tmp_refseq_gene as
    select distinct X.dblabel, X.refvalue, 'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join gene2refseq as G
        on X.refvalue = cast(G.geneid as varchar)
    inner join tmp_refseq_proteins as P
        on G.accession = P.version

    -- Exclude previous matches.

    left outer join tmp_refseq as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_refseq_nucleotide as P3
        on X.refvalue = P3.refvalue
    left outer join tmp_refseq_nucleotide_shortform as P4
        on X.refvalue = P4.refvalue
    where X.dblabel = 'entrezgene'
        and P2.refvalue is null
        and P3.refvalue is null
        and P4.refvalue is null;

-- Use a temporary table to hold new sequence information.

create temporary table tmp_xml_xref_sequences (
    dblabel varchar not null,
    refvalue varchar not null,
    sequencelink varchar,
    reftaxid integer,
    refsequence varchar,
    refdate varchar
);

insert into tmp_xml_xref_sequences
    select * from tmp_refseq
    union all
    select * from tmp_refseq_nucleotide
    union all
    select * from tmp_refseq_nucleotide_shortform
    union all
    select * from tmp_refseq_gene;

create index tmp_xml_xref_sequences_index on tmp_xml_xref_sequences(dblabel, refvalue);
analyze tmp_xml_xref_sequences;

insert into xml_xref_sequences
    select T.*
    from tmp_xml_xref_sequences as T
    left outer join xml_xref_sequences as S
        on (T.dblabel, T.refvalue) = (S.dblabel, S.refvalue)
    where S.refvalue is null;

-- Remove affected records from the interactor sequences mapping, replacing them
-- with usable sequence information.

delete from xml_xref_interactor_sequences
where (dblabel, refvalue) in (
    select dblabel, refvalue
    from tmp_xml_xref_sequences
    );

insert into xml_xref_interactor_sequences
    select source, filename, entry, interactorid, reftype, I.dblabel, I.refvalue,
        taxid, sequence, sequencelink, reftaxid, refsequence, refdate
    from xml_xref_interactors as I
    inner join tmp_xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue);

commit;
