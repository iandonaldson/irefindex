begin;

create table xml_experiments (
    source varchar not null,
    filename varchar not null,
    experimentid integer not null,
    interactionid integer not null
);

\copy xml_experiments from '<directory>/experiment.txt'

alter table xml_experiments add primary key (source, filename, experimentid, interactionid);
analyze xml_experiments;

create table xml_interactors (
    source varchar not null,
    filename varchar not null,
    interactorid integer not null,
    participantid integer not null
);

\copy xml_interactors from '<directory>/interactor.txt'

alter table xml_interactors add primary key (source, filename, interactorid, participantid);
analyze xml_interactors;

create table xml_participants (
    source varchar not null,
    filename varchar not null,
    participantid integer not null,
    interactionid integer not null
);

\copy xml_participants from '<directory>/participant.txt'

alter table xml_participants add primary key (source, filename, participantid, interactionid);
analyze xml_participants;

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

\copy xml_names from '<directory>/names.txt'

delete from xml_names where name is null;
alter table xml_names alter column name set not null;

analyze xml_names;

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

\copy xml_xref from '<directory>/xref.txt'

analyze xml_xref;

create table xml_organisms (
    source varchar not null,
    filename varchar not null,
    scope varchar not null,
    parentid integer not null,
    taxid integer not null
);

\copy xml_organisms from '<directory>/organisms.txt'

analyze xml_organisms;

commit;
