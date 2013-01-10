-- Map identifiers/accessions to sequences for referenced interactors.

-- In this template, the following parameters can be specified:
-- <sequences> may be given as 'irefindex_sequences' or 'irefindex_sequences_archived'
-- <linkprefix> may be given as '' or 'archived/'

-- Copyright (C) 2011, 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

-- Find identifiers in sequence databases.

-- Match plain identifiers mapping to sequences.

create temporary table tmp_plain as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || X.dblabel as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and X.refvalue = P.refvalue;

-- UniProt non-primary accessions.

create temporary table tmp_uniprot_non_primary as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'uniprotkb/non-primary' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X
    inner join uniprot_accessions as A1
        on X.refvalue = A1.accession
    inner join uniprot_accessions as A2
        on A1.uniprotid = A2.uniprotid
        and A1.accession <> A2.accession
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and A2.accession = P.refvalue
    where P.dblabel = 'uniprotkb';

-- UniProt matches for unexpected isoforms.

create temporary table tmp_uniprot_isoform as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'uniprotkb/isoform-primary-unexpected' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X

    -- Match using the base accession.

    inner join <sequences> as P
        on position('-' in X.refvalue) <> 0
        and substring(X.refvalue from 1 for position('-' in X.refvalue) - 1) = P.refvalue
        and X.dblabel = P.dblabel

    -- Exclude existing matches.

    left outer join <sequences> as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where P.dblabel = 'uniprotkb'
        and P2.dblabel is null;

-- UniProt matches for unexpected non-primary accession-based isoforms.

create temporary table tmp_uniprot_non_primary_isoform as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'uniprotkb/isoform-non-primary-unexpected' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X

    -- Match using the base accession.

    inner join uniprot_accessions as A1
        on position('-' in X.refvalue) <> 0
        and substring(X.refvalue from 1 for position('-' in X.refvalue) - 1) = A1.accession
    inner join uniprot_accessions as A2
        on A1.uniprotid = A2.uniprotid
        and A1.accession <> A2.accession
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and A2.accession = P.refvalue
    where P.dblabel = 'uniprotkb';

-- UniProt matches for gene identifiers.

create temporary table tmp_uniprot_gene as
    select distinct X.dblabel, X.refvalue,
        'uniprotkb' as finaldblabel, P.accession as finalrefvalue,
        '<linkprefix>' || 'uniprotkb/entrezgene-symbol' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join irefindex_gene2uniprot as P
        on X.refvalue = cast(P.geneid as varchar)
    where X.dblabel = 'entrezgene/locuslink';

-- UniProt matches for gene identifiers via history.

create temporary table tmp_uniprot_gene_history as
    select distinct X.dblabel, X.refvalue,
        'uniprotkb' as finaldblabel, P.accession as finalrefvalue,
        '<linkprefix>' || 'uniprotkb/entrezgene-symbol-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join gene_history as H
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = H.oldgeneid
    inner join irefindex_gene2uniprot as P
        on H.geneid = P.geneid
    where X.dblabel = 'entrezgene/locuslink';

-- RefSeq accession matches discarding versioning.

create temporary table tmp_refseq_discarding_version as

    -- RefSeq accession matches for otherwise non-matching versions.
    -- The latest version for the matching accession is chosen.

    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'refseq/version-discarded' as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and substring(X.refvalue from 1 for position('.' in X.refvalue) - 1) = P.refvalue
    where X.dblabel = 'refseq'
        and position('.' in X.refvalue) <> 0;

-- RefSeq accession matches via Entrez Gene.

create temporary table tmp_refseq_gene as
    select distinct X.dblabel, X.refvalue,
        'refseq' as finaldblabel, P.accession as finalrefvalue,
        '<linkprefix>' || 'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join irefindex_gene2refseq as P
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = P.geneid
    where X.dblabel = 'entrezgene/locuslink';

-- RefSeq accession matches via Entrez Gene history.

create temporary table tmp_refseq_gene_history as
    select distinct X.dblabel, X.refvalue,
        'refseq' as finaldblabel, P.accession as finalrefvalue,
        '<linkprefix>' || 'refseq/entrezgene-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join gene_history as H
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = H.oldgeneid
    inner join irefindex_gene2refseq as P
        on H.geneid = P.geneid

    -- Exclude existing matches.

    left outer join tmp_refseq_gene as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where X.dblabel = 'entrezgene/locuslink'
        and P2.dblabel is null;

-- UniProt matches via Yeast accessions.

create temporary table tmp_yeast_primary as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'uniprotkb/sgd-primary' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = 'sgd' and P.dblabel = 'sgd' and 'S' || lpad(ltrim(X.refvalue, 'S0'), 9, '0') = P.refvalue
        or X.dblabel = 'cygd' and P.dblabel = 'cygd' and lower(X.refvalue) = lower(P.refvalue)

    -- Exclude existing matches.

    left outer join <sequences> as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where P2.dblabel is null;

-- GenBank protein identifier matches in RefSeq or against accessions.

create temporary table tmp_genpept_genbank_accession as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'genpept/genbank-accession-bad-gi' as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on not X.refvalue ~ '^[[:digit:]]{1,9}$'
        and X.refvalue = P.refvalue
        and P.dblabel in ('refseq', 'ddbj/embl/genbank')
    where X.dblabel = 'genbank_protein_gi';

-- IPI accession matches discarding versioning.

create temporary table tmp_ipi_discarding_version as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'ipi/version-discarded' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and substring(X.refvalue from '[^.]*') = P.refvalue

    -- Exclude existing matches.

    left outer join <sequences> as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where X.dblabel = 'ipi'
        and P2.dblabel is null;

-- PDB accession matches without chain information.

create temporary table tmp_pdb_without_chain as
    select distinct X.dblabel, X.refvalue,
        P.dblabel as finaldblabel, P.refvalue as finalrefvalue,
        '<linkprefix>' || 'pdb/without-chain' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and X.refvalue = substring(P.refvalue from '[^|]*')

    -- Exclude existing matches.

    left outer join <sequences> as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where X.dblabel = 'pdb'
        and P2.dblabel is null;

-- Create a mapping from accessions to reference sequences.
-- Combine the straightforward mapping with those requiring some identifier
-- transformations.
-- Each of the above tables should provide distinct sets of accessions, although
-- some may provide multiple sequences for accessions.

create temporary table tmp_xml_xref_sequences as
    select * from tmp_plain
    union all
    select * from tmp_uniprot_non_primary
    union all
    select * from tmp_uniprot_isoform
    union all
    select * from tmp_uniprot_non_primary_isoform
    union all
    select * from tmp_uniprot_gene
    union all
    select * from tmp_uniprot_gene_history
    union all
    select * from tmp_refseq_discarding_version
    union all
    select * from tmp_refseq_gene
    union all
    select * from tmp_refseq_gene_history
    union all
    select * from tmp_yeast_primary
    union all
    select * from tmp_genpept_genbank_accession
    union all
    select * from tmp_ipi_discarding_version
    union all
    select * from tmp_pdb_without_chain;

create index tmp_xml_xref_sequences_index on tmp_xml_xref_sequences(dblabel, refvalue);
analyze tmp_xml_xref_sequences;

-- Add to any previous table contents.
-- Note that this table contains only sequence information for "active"
-- interactors and not all interactors in the sequence databases.

insert into xml_xref_sequences
    select T.*
    from tmp_xml_xref_sequences as T
    left outer join xml_xref_sequences as S
        on (T.dblabel, T.refvalue) = (S.dblabel, S.refvalue)
    where S.dblabel is null;

analyze xml_xref_sequences;

commit;
