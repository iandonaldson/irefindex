begin;

-- Get interactor cross-references of interest.

insert into xml_xref_all_interactors

    -- Normalise database labels.

    select distinct source, filename, entry, parentid as interactorid, reftype, reftypelabel,
        case when dblabel like 'uniprot%' or dblabel in ('SP', 'Swiss-Prot', 'TREMBL') then 'uniprotkb'
             when dblabel like 'entrezgene%' or dblabel like 'entrez gene%' then 'entrezgene'
             when dblabel like '%pdb' then 'pdb'
             when dblabel in ('protein genbank identifier', 'genbank indentifier') then 'genbank_protein_gi'
             else dblabel
        end as dblabel,
        refvalue
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
    select X.source, X.filename, X.entry, interactorid, X.reftype, X.dblabel, X.refvalue, taxid, sequence
    from xml_xref_all_interactors as X

    -- Add organism and interaction database sequence information.

    left outer join xml_organisms as O
        on (X.source, X.filename, X.entry, X.interactorid, 'interactor') = (O.source, O.filename, O.entry, O.parentid, O.scope)
    left outer join xml_sequences as S
        on (X.source, X.filename, X.entry, X.interactorid, 'interactor') = (S.source, S.filename, S.entry, S.parentid, S.scope)

    -- Exclude non-proteins.

    -- left outer join xml_xref as R
    --    on (X.source, X.filename, X.entry, X.interactorid, 'interactor') = (R.source, R.filename, R.entry, R.parentid, R.scope)
    --    and R.property = 'interactorType'
    --    and R.dblabel = 'psi-mi'

    -- Select specific references.
    -- NOTE: MPACT has secondary references that may be more usable that various
    -- NOTE: primary references (having a UniProt accession of "unknown", for example).
    -- NOTE: HPRD provides its own identifiers for interactor primary references.
    -- NOTE: BIND provides accessions and GenBank identifiers, with the latter treated as
    -- NOTE: secondary references.

    where (
        X.reftype = 'primaryRef'
        or X.reftype = 'secondaryRef' and (X.reftypelabel = 'identity' or X.source = 'MPACT')
        or X.source in ('HPRD', 'BIND')
        )
        and X.dblabel in ('cygd', 'ddbj/embl/genbank', 'entrezgene', 'flybase', 'ipi', 'pdb', 'genbank_protein_gi', 'refseq', 'sgd', 'uniprotkb');

        -- Only interactors that are described as proteins or have no type are considered.

        -- and (R.refvalue = 'MI:0326' or R.refvalue is null);

create index xml_xref_interactors_dblabel_refvalue on xml_xref_interactors(dblabel, refvalue);
analyze xml_xref_interactors;

-- Create a mapping of gene names to UniProt proteins.

insert into gene2uniprot
    select geneid, P.accession, P.sequencedate, P.taxid, P.sequence
    from gene_info as G
    inner join uniprot_gene_names as N
        on G.symbol = N.genename
    inner join uniprot_proteins as P
        on N.uniprotid = P.uniprotid
        and P.taxid = G.taxid;

analyze gene2uniprot;

-- Partition UniProt accession matches since there can be an overlap when
-- different methods are employed.

-- UniProt primary accession matches.

create temporary table tmp_uniprot_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/primary' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join uniprot_proteins as P
        on X.dblabel = 'uniprotkb'
        and X.refvalue = P.accession;

create index tmp_uniprot_primary_refvalue on tmp_uniprot_primary(refvalue);
analyze tmp_uniprot_primary;

-- UniProt non-primary accession matches.

create temporary table tmp_uniprot_non_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/non-primary' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join uniprot_accessions as A
        on X.refvalue = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join tmp_uniprot_primary as P2
        on X.refvalue = P2.refvalue
    where X.dblabel = 'uniprotkb'
        and P2.refvalue is null;

create index tmp_uniprot_non_primary_refvalue on tmp_uniprot_non_primary(refvalue);
analyze tmp_uniprot_non_primary;

-- UniProt primary accession matches for unexpected isoforms.

create temporary table tmp_uniprot_isoform_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/isoform-primary-unexpected' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join uniprot_proteins as P
        on position('-' in X.refvalue) <> 0
        and substring(X.refvalue from 1 for position('-' in X.refvalue) - 1) = P.accession

    -- Exclude previous matches.

    left outer join tmp_uniprot_primary as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_uniprot_non_primary as P3
        on X.refvalue = P3.refvalue
    where X.dblabel = 'uniprotkb'
        and P2.refvalue is null
        and P3.refvalue is null;

create index tmp_uniprot_isoform_primary_refvalue on tmp_uniprot_isoform_primary(refvalue);
analyze tmp_uniprot_isoform_primary;

-- UniProt non-primary accession matches for unexpected isoforms.

create temporary table tmp_uniprot_isoform_non_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/isoform-non-primary-unexpected' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join uniprot_accessions as A
        on position('-' in X.refvalue) <> 0
        and substring(X.refvalue from 1 for position('-' in X.refvalue) - 1) = A.accession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join tmp_uniprot_primary as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_uniprot_non_primary as P3
        on X.refvalue = P3.refvalue
    left outer join tmp_uniprot_isoform_primary as P4
        on X.refvalue = P4.refvalue
    where X.dblabel = 'uniprotkb'
        and P2.refvalue is null
        and P3.refvalue is null
        and P4.refvalue is null;

create index tmp_uniprot_isoform_non_primary_refvalue on tmp_uniprot_isoform_non_primary(refvalue);
analyze tmp_uniprot_isoform_non_primary;

-- UniProt matches for gene identifiers.

create temporary table tmp_uniprot_gene as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/entrezgene-symbol' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join gene2uniprot as P
        on X.refvalue = cast(P.geneid as varchar)

    -- Exclude previous matches.

    left outer join tmp_uniprot_primary as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_uniprot_non_primary as P3
        on X.refvalue = P3.refvalue
    left outer join tmp_uniprot_isoform_primary as P4
        on X.refvalue = P4.refvalue
    left outer join tmp_uniprot_isoform_non_primary as P5
        on X.refvalue = P5.refvalue
    where X.dblabel = 'entrezgene'
        and P2.refvalue is null
        and P3.refvalue is null
        and P4.refvalue is null
        and P5.refvalue is null;

-- UniProt matches for gene identifiers via history.

create temporary table tmp_uniprot_gene_history as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/entrezgene-symbol-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join gene_history as H
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = H.oldgeneid
    inner join gene2uniprot as P
        on H.geneid = P.geneid

    -- Exclude previous matches.

    left outer join tmp_uniprot_primary as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_uniprot_non_primary as P3
        on X.refvalue = P3.refvalue
    left outer join tmp_uniprot_isoform_primary as P4
        on X.refvalue = P4.refvalue
    left outer join tmp_uniprot_isoform_non_primary as P5
        on X.refvalue = P5.refvalue
    left outer join tmp_uniprot_gene as P6
        on X.refvalue = P6.refvalue
    where X.dblabel = 'entrezgene'
        and P2.refvalue is null
        and P3.refvalue is null
        and P4.refvalue is null
        and P5.refvalue is null
        and P6.refvalue is null;

-- Partition RefSeq accession matches.

-- RefSeq accession matches with and without versioning.

create temporary table tmp_refseq as

    -- RefSeq accession matches.
    -- The latest version is always used.

    select distinct 'refseq' as dblabel, X.refvalue, 'refseq' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from (

        -- Get RefSeq entries with the latest version number.

        select X.refvalue, max(P.vnumber) as vnumber
        from xml_xref_interactors as X
        inner join refseq_proteins as P
            on X.dblabel = 'refseq'
            and X.refvalue = P.accession
        group by X.refvalue

        ) as X

    inner join refseq_proteins as P
        on X.refvalue = P.accession
        and X.vnumber = P.vnumber
    union all

    -- RefSeq accession matches using versioning.

    select distinct X.dblabel, X.refvalue, 'refseq' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'refseq'
        and X.refvalue = P.version;

create index tmp_refseq_refvalue on tmp_refseq(refvalue);
analyze tmp_refseq;

-- RefSeq accession matches via nucleotide accessions.

create temporary table tmp_refseq_nucleotide as
    select distinct 'refseq' as dblabel, X.refvalue, 'refseq/nucleotide' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from (

        -- Get RefSeq entries with the latest version number.

        select X.refvalue, P.accession, max(P.vnumber) as vnumber
        from xml_xref_interactors as X
        inner join refseq_nucleotides as N
            on X.refvalue = N.nucleotide
        inner join refseq_proteins as P
            on N.protein = P.accession
        where X.dblabel = 'refseq'
        group by X.refvalue, P.accession

        ) as X

    inner join refseq_proteins as P
        on X.accession = P.accession
        and X.vnumber = P.vnumber

    -- Exclude previous matches.

    left outer join tmp_refseq as P2
        on X.refvalue = P2.refvalue
    where P2.refvalue is null;

create index tmp_refseq_nucleotide_refvalue on tmp_refseq_nucleotide(refvalue);
analyze tmp_refseq_nucleotide;

create temporary table tmp_refseq_nucleotide_shortform as
    select distinct 'refseq' as dblabel, X.refvalue, 'refseq/nucleotide-shortform' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from (

        -- Get RefSeq entries with the latest version number.

        select X.refvalue, P.accession, max(P.vnumber) as vnumber
        from xml_xref_interactors as X
        inner join refseq_nucleotide_accessions as A
            on X.refvalue = A.shortform
        inner join refseq_nucleotides as N
            on A.nucleotide = N.nucleotide
        inner join refseq_proteins as P
            on N.protein = P.accession
        where X.dblabel = 'refseq'
        group by X.refvalue, P.accession

        ) as X

    inner join refseq_proteins as P
        on X.accession = P.accession
        and X.vnumber = P.vnumber

    -- Exclude previous matches.

    left outer join tmp_refseq as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_refseq_nucleotide as P3
        on X.refvalue = P3.refvalue
    where P2.refvalue is null
        and P3.refvalue is null;

create index tmp_refseq_nucleotide_shortform_refvalue on tmp_refseq_nucleotide_shortform(refvalue);
analyze tmp_refseq_nucleotide_shortform;

-- RefSeq accession matches via Entrez Gene.

create temporary table tmp_refseq_gene as
    select distinct X.dblabel, X.refvalue, 'refseq/entrezgene' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join gene2refseq as G
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = G.geneid
    inner join refseq_proteins as P
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

-- RefSeq accession matches via Entrez Gene history.

create temporary table tmp_refseq_gene_history as
    select distinct X.dblabel, X.refvalue, 'refseq/entrezgene-history' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join gene_history as H
        on X.refvalue ~ '^[[:digit:]]*$'
        and cast(X.refvalue as integer) = H.oldgeneid
    inner join gene2refseq as G
        on H.geneid = G.geneid
    inner join refseq_proteins as P
        on G.accession = P.version

    -- Exclude previous matches.

    left outer join tmp_refseq as P2
        on X.refvalue = P2.refvalue
    left outer join tmp_refseq_nucleotide as P3
        on X.refvalue = P3.refvalue
    left outer join tmp_refseq_nucleotide_shortform as P4
        on X.refvalue = P4.refvalue
    left outer join tmp_refseq_gene as P5
        on X.refvalue = P5.refvalue
    where X.dblabel = 'entrezgene'
        and P2.refvalue is null
        and P3.refvalue is null
        and P4.refvalue is null
        and P5.refvalue is null;

-- Partition UniProt matches via FlyBase accessions.

-- FlyBase primary accession matches.

create temporary table tmp_fly_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/flybase-primary' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join fly_accessions as A
        on X.refvalue = A.flyaccession
    inner join uniprot_proteins as P
        on A.accession = P.accession
    where X.dblabel = 'flybase';

create index tmp_fly_primary_refvalue on tmp_fly_primary(refvalue);
analyze tmp_fly_primary;

-- FlyBase non-primary accession matches.

create temporary table tmp_fly_non_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/flybase-non-primary' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join fly_accessions as A
        on X.refvalue = A.flyaccession
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join tmp_fly_primary as P2
        on X.refvalue = P2.refvalue
    where X.dblabel = 'flybase'
        and P2.refvalue is null;

-- Partition UniProt matches via Yeast accessions.

create temporary table tmp_yeast_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/sgd-primary' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join yeast_accessions as A
        on X.dblabel = 'sgd' and 'S' || lpad(ltrim(X.refvalue, 'S0'), 9, '0') = A.sgdxref
        or X.dblabel = 'cygd' and lower(X.refvalue) = lower(A.orderedlocus)
    inner join uniprot_proteins as P
        on A.accession = P.accession;

create index tmp_yeast_primary_refvalue on tmp_yeast_primary(refvalue);
analyze tmp_yeast_primary;

create temporary table tmp_yeast_non_primary as
    select distinct X.dblabel, X.refvalue, 'uniprotkb/sgd-non-primary' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from xml_xref_interactors as X
    inner join yeast_accessions as A
        on X.dblabel = 'sgd' and 'S' || lpad(ltrim(X.refvalue, 'S0'), 9, '0') = A.sgdxref
        or X.dblabel = 'cygd' and lower(X.refvalue) = lower(A.orderedlocus)
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join tmp_yeast_primary as P2
        on X.refvalue = P2.refvalue
    where P2.refvalue is null;

-- GenBank protein identifier matches in RefSeq.

create temporary table tmp_refseq_genbank as
    select distinct X.dblabel, X.refvalue, 'refseq/genbank-gi' as sequencelink,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join refseq_proteins as P
        on X.dblabel = 'genbank_protein_gi'
        and X.refvalue ~ '^[[:digit:]]{1,9}$'
        and cast(X.refvalue as integer) = P.gi;

analyze tmp_refseq_genbank;

-- GenBank matches in GenPept using GenBank identifiers.

create temporary table tmp_genpept_genbank_gi as
    select distinct X.dblabel, X.refvalue, 'genpept/genbank-gi' as sequencelink,
        cast(null as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join genpept_proteins as P
        on X.dblabel = 'genbank_protein_gi'
        and X.refvalue ~ '^[[:digit:]]{1,9}$'
        and cast(X.refvalue as integer) = P.gi

    -- Exclude previous matches.

    left outer join tmp_refseq_genbank as P2
        on X.refvalue = P2.refvalue
    where P2.refvalue is null;

create temporary table tmp_genpept_genbank_accession as
    select distinct X.dblabel, X.refvalue, 'genpept/genbank-accession' as sequencelink,
        cast(null as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join genpept_proteins as P
        on X.dblabel = 'ddbj/embl/genbank'
        and X.refvalue = P.accession
    union all
    select distinct X.dblabel, X.refvalue, 'genpept/genbank-accession-bad-gi' as sequencelink,
        cast(null as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join genpept_proteins as P
        on X.dblabel = 'genbank_protein_gi'
        and not X.refvalue ~ '^[[:digit:]]{1,9}$'
        and X.refvalue = P.accession;

analyze tmp_genpept_genbank_accession;

create temporary table tmp_genpept_genbank_shortform as
    select distinct X.dblabel, X.refvalue, 'genpept/genbank-shortform' as sequencelink,
        cast(null as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join genpept_accessions as A
        on X.dblabel = 'ddbj/embl/genbank'
        and (X.refvalue = A.shortform or
            substring(X.refvalue from '[^.]*') = A.shortform
            )
    inner join genpept_proteins as P
        on A.accession = P.accession

    -- Exclude previous matches.

    left outer join tmp_genpept_genbank_accession as P2
        on X.refvalue = P2.refvalue
    where P2.refvalue is null
    union all
    select distinct X.dblabel, X.refvalue, 'genpept/genbank-shortform-bad-gi' as sequencelink,
        cast(null as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join genpept_accessions as A
        on X.dblabel = 'genbank_protein_gi'
        and not X.refvalue ~ '^[[:digit:]]{1,9}$'
        and (X.refvalue = A.shortform or
            substring(X.refvalue from '[^.]*') = A.shortform
            )
    inner join genpept_proteins as P
        on A.accession = P.accession

    -- Exclude previous matches.

    left outer join tmp_genpept_genbank_accession as P2
        on X.refvalue = P2.refvalue
    where P2.refvalue is null;

-- IPI matches.

create temporary table tmp_ipi_accession as
    select distinct X.dblabel, X.refvalue, 'ipi-accession' as sequencelink,
        cast(T.refvalue as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join ipi_proteins as P
        on X.refvalue = P.accession
    inner join ipi_identifiers as T
        on X.refvalue = T.accession
        and T.dblabel = 'Tax_Id'
    where X.dblabel = 'ipi';

analyze tmp_ipi_accession;

create temporary table tmp_ipi_shortform as
    select distinct X.dblabel, X.refvalue, 'ipi-shortform' as sequencelink,
        cast(T.refvalue as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join ipi_accessions as A
        on (X.refvalue = A.shortform or
            substring(X.refvalue from '[^.]*') = A.shortform
            )
    inner join ipi_proteins as P
        on A.accession = P.accession
    inner join ipi_identifiers as T
        on A.accession = T.accession
        and T.dblabel = 'Tax_Id'

    -- Exclude previous matches.

    left outer join tmp_ipi_accession as P2
        on X.refvalue = P2.refvalue
    where X.dblabel = 'ipi'
        and P2.refvalue is null;

-- PDB accession matches via MMDB.

create temporary table tmp_pdb_mmdb as
    select distinct X.dblabel, X.refvalue, 'pdb/mmdb' as sequencelink,
        M.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join mmdb_pdb_accessions as M
        on X.dblabel = 'pdb'
        and X.refvalue = M.accession
    inner join pdb_proteins as P
        on M.accession = P.accession
        and M.chain = P.chain;

-- PDB accession|chain matches.
-- NOTE: This should give a null taxid and is only of interest if nothing else
-- NOTE: matches for an interactor.

create temporary table tmp_pdb as
    select distinct X.dblabel, X.refvalue, 'pdb' as sequencelink,
        M.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from xml_xref_interactors as X
    inner join pdb_proteins as P
        on X.dblabel = 'pdb'
        and X.refvalue = P.accession || '|' || P.chain
    left outer join mmdb_pdb_accessions as M
        on M.accession = P.accession
        and M.chain = P.chain

    -- Exclude previous matches.

    where M.accession is null;

-- Create a mapping from accessions to reference sequences.
-- Combine the UniProt and RefSeq details with those from other sources.
-- Each source should provide distinct sets of accessions, although some may
-- provide multiple sequences for accessions.

insert into xml_xref_sequences

    -- PDB matches.

    select * from tmp_pdb
    union all
    select * from tmp_pdb_mmdb
    union all

    -- FlyBase matches.

    select * from tmp_fly_primary
    union all
    select * from tmp_fly_non_primary
    union all

    -- Yeast matches.

    select * from tmp_yeast_primary
    union all
    select * from tmp_yeast_non_primary
    union all

    -- UniProt matches.

    select * from tmp_uniprot_primary
    union all
    select * from tmp_uniprot_non_primary
    union all
    select * from tmp_uniprot_isoform_primary
    union all
    select * from tmp_uniprot_isoform_non_primary
    union all
    select * from tmp_uniprot_gene
    union all
    select * from tmp_uniprot_gene_history
    union all

    -- RefSeq matches.

    select * from tmp_refseq
    union all
    select * from tmp_refseq_nucleotide
    union all
    select * from tmp_refseq_nucleotide_shortform
    union all
    select * from tmp_refseq_gene
    union all
    select * from tmp_refseq_gene_history
    union all

    -- GenBank matches.

    select * from tmp_refseq_genbank
    union all
    select * from tmp_genpept_genbank_gi
    union all
    select * from tmp_genpept_genbank_accession
    union all
    select * from tmp_genpept_genbank_shortform
    union all

    -- IPI matches

    select * from tmp_ipi_accession
    union all
    select * from tmp_ipi_shortform;

create index xml_xref_sequences_index on xml_xref_sequences(dblabel, refvalue);
analyze xml_xref_sequences;

-- Combine the interactor details with the identifier sequence details.

insert into xml_xref_interactor_sequences
    select source, filename, entry, interactorid, reftype, I.dblabel, I.refvalue,
        taxid, sequence, sequencelink, reftaxid, refsequence, refdate
    from xml_xref_interactors as I
    left outer join xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue);

create index xml_xref_interactor_sequences_index on xml_xref_interactor_sequences(source, filename, entry, interactorid);
analyze xml_xref_interactor_sequences;

commit;
