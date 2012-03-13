-- Cross-references for interactions.

create table xml_xref_interactions (

    -- From xml_xref:

    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    reftype varchar not null,
    dblabel varchar,
    refvalue varchar not null

    -- Constraints are added after import.
);
