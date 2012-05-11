begin;

-- Get interactor cross-references of interest.

insert into xml_xref_all_interactors
    select distinct source, filename, entry, parentid as interactorid, reftype, reftypelabel,

        -- Normalise database labels.

        case when dblabel like 'uniprot%' or dblabel in ('SP', 'Swiss-Prot', 'TREMBL') then 'uniprotkb'
             when dblabel like 'entrezgene%' or dblabel like 'entrez gene%' then 'entrezgene/locuslink'
             when dblabel like '%pdb' then 'pdb'
             when dblabel in ('protein genbank identifier', 'genbank indentifier') then 'genbank_protein_gi'
             when dblabel in ('MI', 'psimi', 'PSI-MI') then 'psi-mi'

             -- BIND-specific labels.
             -- NOTE: Various accessions can be regarded as GenBank accessions
             -- NOTE: since they can be found in GenBank, but the data involved
             -- NOTE: really originates from other sources.

             when source = 'BIND' and dblabel = 'GenBank' then
                  case when refvalue ~ '^[A-Z]P_[0-9]*([.][0-9]*)?$' then 'refseq'
                       when refvalue ~ E'^[A-Z0-9]{4}\\|[A-Z0-9]$' then 'pdb'
                       when refvalue ~ '^[A-NR-Z][0-9][A-Z][A-Z0-9]{2}[0-9]$|^[OPQ][0-9][A-Z0-9]{3}[0-9]$' then 'uniprotkb'
                       else dblabel
                  end

             else dblabel

        end as dblabel,
        refvalue,

        -- Original identifiers.

        dblabel as originaldblabel,
        refvalue as originalrefvalue

    from xml_xref

    -- Restrict to interactors and specifically to primary and secondary references.

    where scope = 'interactor'
        and property = 'interactor'
        and reftype in ('primaryRef', 'secondaryRef');

-- Make some reports more efficient to generate.

create index xml_xref_all_interactors_index on xml_xref_all_interactors (source);
analyze xml_xref_all_interactors;

-- Narrow the cross-references to those actually describing each interactor
-- using supported databases.

insert into xml_xref_interactors
    select X.source, X.filename, X.entry, X.interactorid, X.reftype, X.reftypelabel,
        X.dblabel, X.refvalue, originaldblabel, originalrefvalue,
        taxid, sequence
    from xml_xref_all_interactors as X

    -- Add organism and interaction database sequence information.

    left outer join xml_organisms as O
        on (X.source, X.filename, X.entry, X.interactorid) = (O.source, O.filename, O.entry, O.parentid)
        and O.scope = 'interactor'
    left outer join xml_sequences as S
        on (X.source, X.filename, X.entry, X.interactorid, 'interactor') = (S.source, S.filename, S.entry, S.parentid, S.scope)

    -- Select specific references.
    -- NOTE: MPACT has secondary references that may be more usable than various
    -- NOTE: primary references (having a UniProt accession of "unknown", for example).
    -- NOTE: HPRD provides its own identifiers for interactor primary references.
    -- NOTE: BIND provides accessions and GenBank identifiers, with the latter treated as
    -- NOTE: secondary references.

    where (
               X.reftype = 'primaryRef'
            or X.reftype = 'secondaryRef' and (X.reftypelabel = 'identity' or X.source = 'MPACT')
            or X.source in ('HPRD', 'BIND')
        )
        and X.dblabel in ('cygd', 'ddbj/embl/genbank', 'entrezgene/locuslink', 'flybase', 'ipi', 'pdb', 'genbank_protein_gi', 'refseq', 'sgd', 'uniprotkb');

create index xml_xref_interactors_dblabel_refvalue on xml_xref_interactors(dblabel, refvalue);
create index xml_xref_interactors_index on xml_xref_interactors(source, filename, entry, interactorid);
analyze xml_xref_interactors;

-- Get interactor types.
-- Only the PSI-MI form of interactor types is of interest.

insert into xml_xref_interactor_types

    -- Normalise database labels.

    select distinct source, filename, entry, parentid as interactorid, refvalue
    from xml_xref

    -- Restrict to interactors and specifically to primary and secondary references.

    where scope = 'interactor'
        and property = 'interactorType'
        and reftype in ('primaryRef', 'secondaryRef')
        and dblabel in ('psi-mi', 'MI', 'PSI-MI', 'psimi');

analyze xml_xref_interactor_types;

-- Create a mapping of gene names to UniProt and RefSeq proteins.
-- This is useful for mapping interactors and for canonicalisation.

insert into irefindex_gene2uniprot
    select geneid, P.accession, P.sequencedate, P.taxid, P.sequence, P.length
    from gene_info as G
    inner join uniprot_gene_names as N
        on G.symbol = N.genename
    inner join uniprot_proteins as P
        on N.uniprotid = P.uniprotid
        and P.taxid = G.taxid
    union
    select geneid, P.accession, P.sequencedate, P.taxid, P.sequence, P.length
    from gene_info as G
    inner join uniprot_identifiers as I
        on G.geneid = cast(I.refvalue as integer)
        and I.dblabel = 'GeneID'
    inner join uniprot_proteins as P
        on I.uniprotid = P.uniprotid;
        -- P.taxid = G.taxid could be used to override any gene association in the UniProt record

analyze irefindex_gene2uniprot;

insert into irefindex_gene2refseq
    select geneid, P.accession, P.taxid, P.sequence, P.length
    from gene2refseq as G
    inner join refseq_proteins as P
        on G.accession = P.version
    union all
    select oldgeneid, P.accession, P.taxid, P.sequence, P.length
    from gene_history as H
    inner join gene2refseq as G
        on H.geneid = G.geneid
    inner join refseq_proteins as P
        on G.accession = P.version;

analyze irefindex_gene2refseq;



-- Find identifiers in sequence databases.

-- Match plain identifiers mapping to sequences.

create temporary table tmp_plain as
    select distinct X.dblabel, X.refvalue, X.dblabel as sequencelink,
        reftaxid, refsequence, refdate
    from xml_xref_interactors as X
    inner join irefindex_sequences as P
        on X.dblabel = P.dblabel
        and X.refvalue = P.refvalue;

-- UniProt matches for unexpected isoforms.

create temporary table tmp_uniprot_isoform as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/isoform-primary-unexpected' as sequencelink,
        P.reftaxid, P.refsequence, P.refdate
    from xml_xref_interactors as X

    -- Match using the base accession.

    inner join irefindex_sequences as P
        on position('-' in X.refvalue) <> 0
        and substring(X.refvalue from 1 for position('-' in X.refvalue) - 1) = P.refvalue
        and X.dblabel = P.dblabel

    -- Exclude existing matches.

    left outer join irefindex_sequences as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where P.dblabel = 'uniprotkb'
        and P2.dblabel is null;

-- UniProt matches for gene identifiers.

create temporary table tmp_uniprot_gene as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/entrezgene-symbol' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join irefindex_gene2uniprot as P
        on X.refvalue = cast(P.geneid as varchar)
    where X.dblabel = 'entrezgene/locuslink';

-- UniProt matches for gene identifiers via history.

create temporary table tmp_uniprot_gene_history as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/entrezgene-symbol-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
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

    select distinct X.dblabel, X.refvalue, 'refseq/version-discarded' as sequencelink,
        reftaxid, refsequence, null as refdate
    from xml_xref_interactors as X
    inner join irefindex_sequences as P
        on X.dblabel = P.dblabel
        and substring(X.refvalue from 1 for position('.' in X.refvalue) - 1) = P.refvalue
    where X.dblabel = 'refseq'
        and position('.' in X.refvalue) <> 0;

-- RefSeq accession matches via Entrez Gene.

create temporary table tmp_refseq_gene as
    select distinct X.dblabel, X.refvalue, 'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join irefindex_gene2refseq as P
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = P.geneid
    where X.dblabel = 'entrezgene/locuslink';

-- RefSeq accession matches via Entrez Gene history.

create temporary table tmp_refseq_gene_history as
    select distinct X.dblabel, X.refvalue, 'refseq/entrezgene-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
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
    select distinct X.dblabel, X.refvalue, 'uniprotkb/sgd-primary' as sequencelink,
        P.reftaxid, P.refsequence, P.refdate
    from xml_xref_interactors as X
    inner join irefindex_sequences as P
        on X.dblabel = 'sgd' and P.dblabel = 'sgd' and 'S' || lpad(ltrim(X.refvalue, 'S0'), 9, '0') = P.refvalue
        or X.dblabel = 'cygd' and P.dblabel = 'cygd' and lower(X.refvalue) = lower(P.refvalue)

    -- Exclude existing matches.

    left outer join irefindex_sequences as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where P2.dblabel is null;

-- GenBank protein identifier matches in RefSeq.

create temporary table tmp_genpept_genbank_accession as
    select distinct X.dblabel, X.refvalue, 'genpept/genbank-accession-bad-gi' as sequencelink,
        reftaxid, refsequence, refdate
    from xml_xref_interactors as X
    inner join irefindex_sequences as P
        on not X.refvalue ~ '^[[:digit:]]{1,9}$'
        and X.refvalue = P.refvalue
    where X.dblabel = 'genbank_protein_gi';

-- IPI accession matches discarding versioning.

create temporary table tmp_ipi_discarding_version as
    select distinct X.dblabel, X.refvalue, 'ipi/version-discarded' as sequencelink,
        P.reftaxid, P.refsequence, P.refdate
    from xml_xref_interactors as X
    inner join irefindex_sequences as P
        on X.dblabel = P.dblabel
        and substring(X.refvalue from '[^.]*') = P.refvalue

    -- Exclude existing matches.

    left outer join irefindex_sequences as P2
        on (X.dblabel, X.refvalue) = (P2.dblabel, P2.refvalue)
    where X.dblabel = 'ipi'
        and P2.dblabel is null;



-- Create a mapping from accessions to reference sequences.
-- Combine the straightforward mapping with those requiring some identifier
-- transformations.
-- Each of the above tables should provide distinct sets of accessions, although
-- some may provide multiple sequences for accessions.

insert into xml_xref_sequences
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

create index xml_xref_sequences_index on xml_xref_sequences(dblabel, refvalue);
analyze xml_xref_sequences;

-- Obtain unmapped accessions.
-- Use archived information to map these accessions to sequences.

insert into xml_xref_sequences
    select distinct X.dblabel, X.refvalue, X.dblabel || '/archived' as sequencelink,
        reftaxid, refsequence, null as refdate
    from (
        select distinct X.dblabel, X.refvalue
        from xml_xref_interactors as X
        left outer join xml_xref_sequences as S
            on (X.dblabel, X.refvalue) = (S.dblabel, S.refvalue)
        where S.dblabel is null
        ) as X
    inner join irefindex_sequences_archived as P
        on X.dblabel = P.dblabel
        and X.refvalue = P.refvalue;

analyze xml_xref_sequences;

-- Combine the interactor details with the identifier sequence details.

insert into xml_xref_interactor_sequences
    select source, filename, entry, interactorid, reftype, reftypelabel,
        I.dblabel, I.refvalue, I.originaldblabel, I.originalrefvalue, missing,
        taxid, sequence, sequencelink, reftaxid, refsequence, refdate
    from xml_xref_interactors as I
    left outer join xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue);

create index xml_xref_interactor_sequences_index on xml_xref_interactor_sequences(source, filename, entry, interactorid);
analyze xml_xref_interactor_sequences;

commit;
