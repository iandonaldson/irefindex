-- Cross-references for interactions.

create table xml_xref_interactions (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    dblabel varchar,
    refvalue varchar not null,
    primary key(source, filename, entry, interactionid)
);

create table xml_xref_interaction_types (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, interactionid)
);
