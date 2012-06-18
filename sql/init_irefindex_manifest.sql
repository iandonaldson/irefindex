create table irefindex_manifest (
    source varchar not null,
    releasedate date not null,
    releaseurl varchar not null,
    downloadfiles varchar,
    version varchar,
    primary key(source)
);
