create table bind_interactors (
    filename varchar not null,
    participantid integer not null,
    interaction integer not null,
    bindid integer not null,
    participantType varchar not null,
    database varchar not null,
    accession varchar not null,
    gi varchar not null,
    taxid integer not null,
    interactorid integer not null
);

create table bind_complexes (
    filename varchar not null,
    bindid integer not null,
    participantType varchar not null,
    database varchar not null,
    accession varchar not null,
    gi varchar not null,
    taxid integer not null,
    shortLabel varchar not null,
    position integer not null,
    alias varchar not null,
    interactorid integer not null
);

create table bind_references (
    reference integer not null,
    bindid integer not null,
    pmid varchar not null,
    method varchar
);

create table bind_complex_references (
    bindid integer not null,
    pmid varchar not null
);

create table bind_labels (
    participantid integer not null,
    bindid integer not null,
    shortLabel varchar not null,
    position integer not null,
    alias varchar not null
);
