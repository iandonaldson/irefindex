create table irefindex_confidence (
    rigid varchar not null,
    scoretype varchar not null,
    score integer not null,
    primary key(rigid, scoretype)
);
