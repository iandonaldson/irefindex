create table irefindex_rigids (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    rigid varchar not null,
    primary key(source, filename, entry, interactionid)
);
