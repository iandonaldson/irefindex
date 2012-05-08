begin;

-- UniProt accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'uniprotkb' as dblabel, accession as refvalue,
        taxid as reftaxid, sequence as refsequence, sequencedate as refdate
    from uniprot_proteins as P
    union all
    select distinct 'uniprotkb' as dblabel, A.accession as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from uniprot_accessions as A
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join uniprot_proteins as P2
        on A.accession = P2.accession
    where P2.accession is null;

-- RefSeq versions and accessions mapping directly to proteins.
-- RefSeq nucleotides mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'refseq' as dblabel, version as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from refseq_proteins as P
    union all
    select distinct 'refseq' as dblabel, accession as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from refseq_proteins as P
    union all
    select distinct 'refseq' as dblabel, nucleotide as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from refseq_nucleotides as N
    inner join refseq_proteins as P
        on N.protein = P.accession
    union all
    select distinct 'refseq' as dblabel, shortform as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from refseq_nucleotide_accessions as A
    inner join refseq_nucleotides as N
        on A.nucleotide = N.nucleotide
    inner join refseq_proteins as P
        on N.protein = P.accession

    -- Exclude previous matches.

    left outer join refseq_proteins as P2
        on A.shortform = P2.accession
    where P2.accession is null;

-- FlyBase accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'flybase' as dblabel, flyaccession as refvalue,
        taxid as reftaxid, sequence as refsequence, sequencedate as refdate
    from fly_accessions as A
    inner join uniprot_proteins as P
        on A.accession = P.accession
    union all
    select distinct 'flybase' as dblabel, flyaccession as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from fly_accessions as A
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join uniprot_proteins as P2
        on A.accession = P2.accession
    where P2.accession is null;

-- SGD accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'sgd' as dblabel, sgdxref as refvalue,
        taxid as reftaxid, sequence as refsequence, sequencedate as refdate
    from yeast_accessions as A
    inner join uniprot_proteins as P
        on A.accession = P.accession
    union all
    select distinct 'sgd' as dblabel, sgdxref as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from yeast_accessions as A
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join uniprot_proteins as P2
        on A.accession = P2.accession
    where P2.accession is null;

-- CYGD accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'cygd' as dblabel, orderedlocus as refvalue,
        taxid as reftaxid, sequence as refsequence, sequencedate as refdate
    from yeast_accessions as A
    inner join uniprot_proteins as P
        on A.accession = P.accession
    union
    select distinct 'cygd' as dblabel, orderedlocus as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, P.sequencedate as refdate
    from yeast_accessions as A
    inner join uniprot_proteins as P
        on A.uniprotid = P.uniprotid

    -- Exclude previous matches.

    left outer join uniprot_proteins as P2
        on A.accession = P2.accession
    where P2.accession is null;

-- GenBank identifiers mapping directly and indirectly to proteins for both
-- RefSeq and GenPept.

insert into irefindex_sequences
    select distinct 'genbank_protein_gi' as dblabel, cast(gi as varchar) as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from refseq_proteins as P
    union all
    select distinct 'genbank_protein_gi' as dblabel, cast(gi as varchar) as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from genpept_proteins as P
    union all
    select distinct 'genbank_protein_gi' as dblabel, cast(gi as varchar) as refvalue,
        P.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from genpept_accessions as A
    inner join genpept_proteins as P
        on A.accession = P.accession;

-- GenBank accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'ddbj/embl/genbank' as dblabel, accession as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from genpept_proteins as P
    union all
    select distinct 'ddbj/embl/genbank' as dblabel, shortform as refvalue,
        taxid as reftaxid, sequence as refsequence, null as refdate
    from genpept_accessions as A
    inner join genpept_proteins as P
        on A.accession = P.accession;

-- IPI accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'ipi' as dblabel, P.accession as refvalue,
        cast(T.refvalue as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from ipi_proteins as P
    inner join ipi_identifiers as T
        on P.accession = T.accession
        and T.dblabel = 'Tax_Id'
    union all
    select distinct 'ipi' as dblabel, shortform as refvalue,
        cast(T.refvalue as integer) as reftaxid, P.sequence as refsequence, null as refdate
    from ipi_accessions as A
    inner join ipi_proteins as P
        on A.accession = P.accession
    inner join ipi_identifiers as T
        on P.accession = T.accession
        and T.dblabel = 'Tax_Id'

    -- Exclude previous matches.

    left outer join uniprot_proteins as P2
        on A.accession = P2.accession
    where P2.accession is null;

-- PDB accessions mapping directly and indirectly to proteins.

insert into irefindex_sequences
    select distinct 'pdb' as dblabel, M.accession as refvalue,
        M.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from mmdb_pdb_accessions as M
    inner join pdb_proteins as P
        on M.accession = P.accession
        and M.chain = P.chain
    union all
    select distinct 'pdb' as dblabel, P.accession || '|' || P.chain as refvalue,
        M.taxid as reftaxid, P.sequence as refsequence, null as refdate
    from pdb_proteins as P
    left outer join mmdb_pdb_accessions as M
        on M.accession = P.accession
        and M.chain = P.chain

    -- Exclude previous matches.

    where M.accession is null;

create index irefindex_sequences_index on irefindex_sequences(dblabel, refvalue);
analyze irefindex_sequences;

commit;
