begin;

alter table irefindex_entities add primary key (source, filename, scope, parentid, db, acc);
analyze irefindex_entities;

commit;
