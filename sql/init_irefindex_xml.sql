begin;

create table xml_experiments (
    source varchar not null,
    filename varchar not null,
    experimentid integer not null,
    interactionid integer not null
);

create table xml_interactors (
    source varchar not null,
    filename varchar not null,
    interactorid integer not null,
    participantid integer not null
);

create table xml_participants (
    source varchar not null,
    filename varchar not null,
    participantid integer not null,
    interactionid integer not null
);

create table xml_names (
    source varchar not null,
    filename varchar not null,
    scope varchar not null,
    parentid integer not null,
    property varchar not null,
    nametype varchar not null,
    typelabel varchar,
    typecode varchar,
    name varchar -- some names can actually be unspecified
);

create table xml_xref (
    source varchar not null,
    filename varchar not null,
    scope varchar not null,
    parentid integer not null,
    property varchar not null,
    reftype varchar not null,
    refvalue varchar not null,
    dblabel varchar,
    dbcode varchar,
    reftypelabel varchar,
    reftypecode varchar
);

create table xml_organisms (
    source varchar not null,
    filename varchar not null,
    scope varchar not null,
    parentid integer not null,
    taxid integer not null
);

commit;
