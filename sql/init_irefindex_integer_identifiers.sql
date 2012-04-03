create table irefindex_rig2rigid (
    rig integer not null,
    rigid varchar not null,
    known boolean not null,
    primary key(rig)
);

create table irefindex_rog2rogid (
    rog integer not null,
    rogid varchar not null,
    known boolean not null,
    primary key(rog)
);
