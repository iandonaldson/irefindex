begin;

create temporary table tmp_sequences_archived_original as
    select A.sequence, A.actualsequence, A.dblabel
    from irefindex_sequences_archived_original as A
    left outer join irefindex_sequences_original as S
        on A.sequence = S.sequence
    where S.sequence is null

    -- Add archived sequences from the previous release that do not conflict with
    -- those from active data. See also export_irefindex_archived.sql for similar
    -- work for the sequence digests.

    union
    select S.sequence, S.actualsequence, S.dblabel 
    from irefindex_sequences_original as S;

\copy tmp_sequences_archived_original to '<directory>/sequences_archived_original'

rollback;
