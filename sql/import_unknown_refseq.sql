-- Import data into the schema for previously unknown or missing sequences.

-- Copyright (C) 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
-- Original author: Paul Boddie <paul.boddie@biotek.uio.no>
--
-- This program is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.

begin;

-- Import the actual data into temporary tables for further processing.

create temporary table tmp_refseq_proteins (
    accession varchar,
    version varchar,
    gi integer not null,
    taxid integer,
    actualsequence varchar not null,
    "sequence" varchar not null,
    length integer not null
);

create temporary table tmp_refseq_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null
);

-- A mapping from protein records to nucleotide records.

create temporary table tmp_refseq_nucleotides (
    nucleotide varchar not null,
    protein varchar not null
);

create temporary table tmp_refseq_nucleotide_accessions (
    nucleotide varchar not null,
    shortform varchar not null,
    primary key(nucleotide)
);

\copy tmp_refseq_proteins from '<directory>/refseq_proteins.txt.seq'

create index tmp_refseq_proteins_sequence on tmp_refseq_proteins(sequence);
analyze tmp_refseq_proteins;

\copy tmp_refseq_identifiers from '<directory>/refseq_identifiers.txt'
\copy tmp_refseq_nucleotides from '<directory>/refseq_nucleotides.txt'

insert into tmp_refseq_nucleotide_accessions
    select distinct T.nucleotide, substring(T.nucleotide from '[^.]*') as shortform
    from tmp_refseq_nucleotides as T;

create index tmp_refseq_proteins_gi on tmp_refseq_proteins(gi);
create index tmp_refseq_identifiers_accession on tmp_refseq_identifiers(accession);
create index tmp_refseq_nucleotides_nucleotide on tmp_refseq_nucleotides(nucleotide);

analyze tmp_refseq_proteins;
analyze tmp_refseq_identifiers;
analyze tmp_refseq_nucleotides;
analyze tmp_refseq_nucleotide_accessions;



-- Augment the existing tables.

insert into refseq_proteins
    select distinct T.accession, T.version,
        case when position('.' in T.version) <> 0 then
            cast(substring(T.version from position('.' in T.version) + 1) as integer)
        else null end as vnumber,
        T.gi, T.taxid, T.sequence, T.length, true as missing
    from tmp_refseq_proteins as T
    left outer join refseq_proteins as P
        on T.gi = P.gi
    where P.gi is null;

analyze refseq_proteins;

insert into refseq_sequences
    select distinct T.sequence, T.actualsequence
    from tmp_refseq_proteins as T
    left outer join refseq_sequences as S
        on T.sequence = S.sequence
    where S.sequence is null;

analyze refseq_sequences;

insert into refseq_identifiers
    select distinct T.accession, T.dblabel, T.refvalue, T.position, true as missing
    from tmp_refseq_identifiers as T
    left outer join refseq_identifiers as I
        on T.accession = I.accession
        and T.dblabel = I.dblabel
        and T.refvalue = I.refvalue
    where I.accession is null;

analyze refseq_identifiers;

insert into refseq_nucleotides
    select distinct T.nucleotide, T.protein, true as missing
    from tmp_refseq_nucleotides as T
    left outer join refseq_nucleotides as N
        on T.nucleotide = N.nucleotide
        and T.protein = N.protein
    where N.nucleotide is null;

analyze refseq_nucleotides;

insert into refseq_nucleotide_accessions
    select T.nucleotide, T.shortform, true as missing
    from tmp_refseq_nucleotide_accessions as T
    left outer join refseq_nucleotide_accessions as A
        on T.nucleotide = A.nucleotide
    where A.nucleotide is null;

analyze refseq_nucleotide_accessions;



-- Augment the gene mapping with new protein information.

create temporary table tmp_irefindex_gene2refseq as
    select X.geneid, X.accession, X.taxid, X.sequence, X.length, true as missing
    from (
        select geneid, P.accession, P.taxid, P.sequence, P.length
        from gene2refseq as G
        inner join tmp_refseq_proteins as P
            on G.accession = P.version
        union all
        select oldgeneid, P.accession, P.taxid, P.sequence, P.length
        from gene_history as H
        inner join gene2refseq as G
            on H.geneid = G.geneid
        inner join tmp_refseq_proteins as P
            on G.accession = P.version
        ) as X

    -- Exclude existing records.

    left outer join irefindex_gene2refseq as G
        on X.geneid = G.geneid
        and X.accession = G.accession
        and X.taxid = G.taxid
        and X.sequence = G.sequence
    where G.geneid is null;

analyze tmp_irefindex_gene2refseq;

insert into irefindex_gene2refseq
    select geneid, accession, taxid, sequence, length, missing
    from tmp_irefindex_gene2refseq;



-- Augment the sequences archive.
-- See import_irefindex_sequences.sql for similar code.

-- RefSeq versions and accessions mapping directly to proteins.
-- RefSeq nucleotides mapping directly and indirectly to proteins.

create temporary table tmp_irefindex_sequences_updated as

    -- Versions and accessions are distinct in the proteins table.

    select 'refseq' as dblabel, version as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from tmp_refseq_proteins as P
    where version is not null
    union all
    select 'refseq' as dblabel, accession as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from tmp_refseq_proteins as P
    where accession is not null
    union all

    -- Nucleotides can be mapped to a number of different proteins.

    -- Completely new nucleotide and protein records.

    select distinct 'refseq' as dblabel, nucleotide as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from tmp_refseq_nucleotides as N
    inner join tmp_refseq_proteins as P
        on N.protein = P.accession
    union

    -- Completely new nucleotide records.

    select distinct 'refseq' as dblabel, nucleotide as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from tmp_refseq_nucleotides as N
    inner join refseq_proteins as P
        on N.protein = P.accession
    union

    -- Completely new protein records.

    select distinct 'refseq' as dblabel, nucleotide as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from refseq_nucleotides as N
    inner join tmp_refseq_proteins as P
        on N.protein = P.accession
    union all

    -- Completely new nucleotide and protein records.

    select distinct 'refseq' as dblabel, shortform as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_refseq_nucleotide_accessions as A
    inner join tmp_refseq_nucleotides as N
        on A.nucleotide = N.nucleotide
    inner join refseq_proteins as P
        on N.protein = P.accession
    union

    -- Completely new nucleotide records.

    select distinct 'refseq' as dblabel, shortform as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from tmp_refseq_nucleotide_accessions as A
    inner join tmp_refseq_nucleotides as N
        on A.nucleotide = N.nucleotide
    inner join refseq_proteins as P
        on N.protein = P.accession
    union

    -- Completely new protein records.

    select distinct 'refseq' as dblabel, shortform as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from refseq_nucleotide_accessions as A
    inner join refseq_nucleotides as N
        on A.nucleotide = N.nucleotide
    inner join tmp_refseq_proteins as P
        on N.protein = P.accession
    union all

    -- Completely new protein records referenced using GenBank identifiers.

    select 'genbank_protein_gi' as dblabel, cast(gi as varchar) as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from tmp_refseq_proteins;

create index tmp_irefindex_sequences_updated_index on tmp_irefindex_sequences_updated(dblabel, refvalue);
analyze tmp_irefindex_sequences_updated;

create temporary table tmp_irefindex_sequences as
    select X.dblabel, X.refvalue, X.reftaxid, X.refsequence, X.refdate
    from tmp_irefindex_sequences_updated as X

    -- Exclude previous matches.

    left outer join irefindex_sequences as P2
        on X.dblabel = P2.dblabel
        and X.refvalue = P2.refvalue
    where P2.dblabel is null;

create index tmp_irefindex_sequences_index on tmp_irefindex_sequences(dblabel, refvalue);
analyze tmp_irefindex_sequences;

insert into irefindex_sequences
    select *
    from tmp_irefindex_sequences;

analyze irefindex_sequences;



-- Augment the interactor tables.
-- See import_irefindex_identifier_sequences.sql for similar code.

-- Match plain identifiers mapping to sequences.

create temporary table tmp_plain as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        X.dblabel as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join tmp_irefindex_sequences as P
        on X.dblabel = P.dblabel
        and X.refvalue = P.refvalue
    where X.dblabel in ('refseq', 'genbank_protein_gi');

-- RefSeq accession matches discarding versioning.

create temporary table tmp_refseq_discarding_version as

    -- RefSeq accession matches for otherwise non-matching versions.
    -- The latest version for the matching accession is chosen.

    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        'refseq/version-discarded' as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join tmp_irefindex_sequences as P
        on X.dblabel = P.dblabel
        and substring(X.refvalue from 1 for position('.' in X.refvalue) - 1) = P.refvalue
    where X.dblabel = 'refseq'
        and position('.' in X.refvalue) <> 0;

-- RefSeq accession matches via Entrez Gene.

create temporary table tmp_refseq_gene as
    select distinct X.dblabel, X.refvalue,
        'refseq' as finaldblabel, P.accession as finalrefvalue,
        'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join tmp_irefindex_gene2refseq as P
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = P.geneid
    where X.dblabel = 'entrezgene/locuslink';

-- RefSeq accession matches via Entrez Gene history.

create temporary table tmp_refseq_gene_history as
    select distinct X.dblabel, X.refvalue,
        'refseq' as finaldblabel, P.accession as finalrefvalue,
        'refseq/entrezgene-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join gene_history as H
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = H.oldgeneid
    inner join tmp_irefindex_gene2refseq as P
        on H.geneid = P.geneid

    -- Exclude existing matches.

    left outer join tmp_refseq_gene as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where X.dblabel = 'entrezgene/locuslink'
        and P2.dblabel is null;



-- Use a temporary table to hold new sequence information.

create temporary table tmp_xml_xref_sequences (
    dblabel varchar not null,
    refvalue varchar not null,
    finaldblabel varchar not null,
    finalrefvalue varchar not null,
    sequencelink varchar,
    reftaxid integer,
    refsequence varchar,
    missing boolean not null default true
);

insert into tmp_xml_xref_sequences
    select * from tmp_plain
    union all
    select * from tmp_refseq_discarding_version
    union all
    select * from tmp_refseq_gene
    union all
    select * from tmp_refseq_gene_history;

create index tmp_xml_xref_sequences_index on tmp_xml_xref_sequences(dblabel, refvalue);
analyze tmp_xml_xref_sequences;



-- Update the identifier-to-sequence mapping with the new information.

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
    select source, filename, entry, interactorid, reftype, reftypelabel,
        I.dblabel, I.refvalue,
        originaldblabel, originalrefvalue, finaldblabel, finalrefvalue, missing,
        taxid, sequence, sequencelink, reftaxid, refsequence
    from xml_xref_interactors as I
    inner join tmp_xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue);

commit;
