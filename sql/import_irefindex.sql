begin;

create table tmp_experiments (
    source varchar not null,
    filename varchar not null,
    experimentid integer not null,
    interactionid integer not null
);

\copy tmp_experiments from '<directory>/experiment.txt'

analyze tmp_experiments;

create table tmp_interactors (
    source varchar not null,
    filename varchar not null,
    interactorid integer not null,
    interactionid integer not null
);

\copy tmp_interactors from '<directory>/interactor.txt'

analyze tmp_interactors;

create table tmp_names (
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

\copy tmp_names from '<directory>/names.txt'

analyze tmp_names;

create table tmp_xref (
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

\copy tmp_xref from '<directory>/xref.txt'

analyze tmp_xref;

create table tmp_organisms (
    source varchar not null,
    filename varchar not null,
    scope varchar not null,
    parentid integer not null,
    taxid integer not null
);

\copy tmp_organisms from '<directory>/organisms.txt'

analyze tmp_organisms;

commit;
