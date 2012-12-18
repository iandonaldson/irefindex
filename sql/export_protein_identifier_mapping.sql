begin;

-- Provide a mapping similar to irefindex_rogid_identifiers but covering all
-- known sequences.

create temporary table tmp_protein_identifiers as
    select dblabel, refvalue, refsequence || reftaxid as rogid
    from irefindex_sequences
    where refsequence is not null and reftaxid is not null
        and dblabel in ('pdb', 'refseq', 'uniprotkb');

analyze tmp_protein_identifiers;

delete from tmp_protein_identifiers
    where rogid in (
        select rogid
        from tmp_protein_identifiers
        where dblabel in ('refseq', 'uniprotkb')
        )
        and dblabel not in ('refseq', 'uniprotkb');

create temporary table tmp_protein_identifier_mapping as
    select
        dblabel,
        refvalue,
        coalesce(geneid, -1) as geneid,
        I.rog,
        R.rogid,
        CI.rog as crog,
        C.crogid as crogid

    -- Provide a mapping for all known sequences.

    from tmp_protein_identifiers as R

    -- Obtain integer identifiers.

    left outer join irefindex_rog2rogid as I
        on R.rogid = I.rogid

    -- Obtain canonical information for the full range of sequences.

    left outer join irefindex_sequence_rogids_canonical as C
        on R.rogid = C.rogid
    left outer join irefindex_rog2rogid as CI
        on C.crogid = CI.rogid

    -- Gene information for RefSeq records.

    left outer join irefindex_gene2refseq as G
        on dblabel = 'refseq'
        and refvalue = G.accession;

\copy tmp_protein_identifier_mapping to '<directory>/mappings.txt'

rollback;
