-- Cross-references for interactions.

create table xml_xref_all_interactions (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    dblabel varchar,
    refvalue varchar not null,
    reftype varchar not null,
    reftypelabel varchar
);

create table xml_xref_interactions (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    dblabel varchar,
    refvalue varchar not null,
    primary key(source, filename, entry, interactionid)
);

-- NOTE: There is usually only one type per interaction, but MPIDB appears to
-- NOTE: provide one per experiment applying to an interaction.

create table xml_xref_interaction_types (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, interactionid, refvalue)
);

create table xml_names_interaction_names (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    nametype varchar not null,
    name varchar not null,
    primary key(source, filename, entry, interactionid, nametype, name)
);
