create table irefindex_obsolete (
    dblabel varchar not null,
    refvalue varchar not null,
    sequence varchar not null,
    taxid integer not null,
    primary key(dblabel, refvalue)
);
