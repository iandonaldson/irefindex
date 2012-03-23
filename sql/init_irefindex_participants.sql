-- Cross-references for participants.

create table xml_xref_participants (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    participantid varchar not null,
    property varchar not null,
    refvalue varchar not null
);
