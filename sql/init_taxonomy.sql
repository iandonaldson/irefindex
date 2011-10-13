-- A simple schema purely for completing interactor data.

create table taxonomy_names (
    taxid integer not null,
    name varchar not null,
    uniquename varchar not null,
    nameclass varchar not null,
    primary key(taxid, name, nameclass)
);
