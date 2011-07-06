begin;

alter table irefindex_entities drop constraint irefindex_entities_pkey;
analyze irefindex_entities;

commit;
