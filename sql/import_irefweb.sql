begin;

create temporary sequence tmp_source_db_seq;

insert into irefweb_source_db
    select nextval('tmp_source_db_seq'), <version>, source, releasedate,
        coalesce(version, to_char(releasedate, 'YYYY-MM-DD'))
    from irefindex_manifest;

commit;
