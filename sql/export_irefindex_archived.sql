begin;

create temporary table tmp_sequences_archived as
    select distinct dblabel, refvalue, reftaxid, refsequence
    from irefindex_sequences;

analyze tmp_sequences_archived;

-- Add archived sequences from the previous release that do not conflict with
-- those from active data. See also import_irefindex_assignments.sql for similar
-- work when constructing the irefindex_rogid_identifiers table.

insert into tmp_sequences_archived
    select distinct dblabel, refvalue, reftaxid, refsequence
    from irefindex_sequences_archived as A
    left outer join tmp_sequences_archived as S
        on A.reftaxid || A.refsequence = S.reftaxid, S.refsequence
        or (A.dblabel, A.refvalue) = (S.dblabel, S.refvalue)
    where S.refvalue is null;

\copy tmp_sequences_archived to '<directory>/sequences_archived'

rollback;
