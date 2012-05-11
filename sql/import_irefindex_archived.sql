begin;

\copy irefindex_sequences_archived from '<directory>/sequences_archived'

create index irefindex_sequences_archived_index on irefindex_sequences_archived(dblabel, refvalue);
analyze irefindex_sequences_archived;

commit;
