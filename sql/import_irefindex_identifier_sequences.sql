begin;

-- Find identifiers in sequence databases.

-- Match plain identifiers mapping to sequences.

create temporary table tmp_plain as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || X.dblabel as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and X.refvalue = P.refvalue;

-- UniProt matches for unexpected isoforms.

create temporary table tmp_uniprot_isoform as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'uniprotkb/isoform-primary-unexpected' as sequencelink,
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

-- UniProt matches for gene identifiers.

create temporary table tmp_uniprot_gene as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'uniprotkb/entrezgene-symbol' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join irefindex_gene2uniprot as P
        on X.refvalue = cast(P.geneid as varchar)
    where X.dblabel = 'entrezgene/locuslink';

-- UniProt matches for gene identifiers via history.

create temporary table tmp_uniprot_gene_history as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'uniprotkb/entrezgene-symbol-history' as sequencelink,
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

    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'refseq/version-discarded' as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = P.dblabel
        and substring(X.refvalue from 1 for position('.' in X.refvalue) - 1) = P.refvalue
    where X.dblabel = 'refseq'
        and position('.' in X.refvalue) <> 0;

-- RefSeq accession matches via Entrez Gene.

create temporary table tmp_refseq_gene as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence
    from xml_xref_interactors as X
    inner join irefindex_gene2refseq as P
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = P.geneid
    where X.dblabel = 'entrezgene/locuslink';

-- RefSeq accession matches via Entrez Gene history.

create temporary table tmp_refseq_gene_history as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'refseq/entrezgene-history' as sequencelink,
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
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'uniprotkb/sgd-primary' as sequencelink,
        P.reftaxid, P.refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on X.dblabel = 'sgd' and P.dblabel = 'sgd' and 'S' || lpad(ltrim(X.refvalue, 'S0'), 9, '0') = P.refvalue
        or X.dblabel = 'cygd' and P.dblabel = 'cygd' and lower(X.refvalue) = lower(P.refvalue)

    -- Exclude existing matches.

    left outer join <sequences> as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where P2.dblabel is null;

-- GenBank protein identifier matches in RefSeq.

create temporary table tmp_genpept_genbank_accession as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'genpept/genbank-accession-bad-gi' as sequencelink,
        reftaxid, refsequence
    from xml_xref_interactors as X
    inner join <sequences> as P
        on not X.refvalue ~ '^[[:digit:]]{1,9}$'
        and X.refvalue = P.refvalue
    where X.dblabel = 'genbank_protein_gi';

-- IPI accession matches discarding versioning.

create temporary table tmp_ipi_discarding_version as
    select distinct X.dblabel, X.refvalue, '<linkprefix>' || 'ipi/version-discarded' as sequencelink,
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

-- Create a mapping from accessions to reference sequences.
-- Combine the straightforward mapping with those requiring some identifier
-- transformations.
-- Each of the above tables should provide distinct sets of accessions, although
-- some may provide multiple sequences for accessions.

create temporary table tmp_xml_xref_sequences as
    select * from tmp_plain
    union all
    select * from tmp_uniprot_isoform
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
    select * from tmp_ipi_discarding_version;

create index tmp_xml_xref_sequences_index on tmp_xml_xref_sequences(dblabel, refvalue);
analyze tmp_xml_xref_sequences;

insert into xml_xref_sequences
    select T.*
    from tmp_xml_xref_sequences as T
    left outer join xml_xref_sequences as S
        on (T.dblabel, T.refvalue) = (S.dblabel, S.refvalue)
    where S.dblabel is null;

analyze xml_xref_sequences;

commit;
