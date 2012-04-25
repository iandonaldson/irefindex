create table irefindex_manifest (
    source varchar not null,
    releasedate date not null,
    version varchar,
    primary key(source)
);
