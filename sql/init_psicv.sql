create table psicv_terms (
    code varchar not null,
    name varchar not null,
    nametype varchar not null,
    primary key(code, name, nametype)
);
