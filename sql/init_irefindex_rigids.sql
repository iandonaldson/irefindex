create table irefindex_rigids (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactionid varchar not null,
    rigid varchar not null,
    primary key(source, filename, entry, interactionid)
);

-- A table corresponding to xml_interactors but with ROG and RIG identifiers.

create table irefindex_interactions (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null,
    participantid varchar not null,
    interactionid varchar not null,

    -- Additional iRefIndex information.

    rogid varchar not null,
    rigid varchar not null,
    primary key(source, filename, entry, interactorid, participantid, interactionid)
);

-- A table providing a mapping from RIG identifiers to the ROG identifiers used
-- in their construction, without referencing individual interaction records.

create table irefindex_distinct_interactions (
    rigid varchar not null,
    rogid varchar not null
);
