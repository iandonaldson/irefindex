begin;

create temporary table tmp_sequences_archived as
    select distinct dblabel, refvalue, reftaxid, refsequence
    from irefindex_sequences;

\copy tmp_sequences_archived to '<directory>/sequences_archived'

rollback;
