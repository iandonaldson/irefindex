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

commit;
