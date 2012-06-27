-- Cross-references for experiments.

create table xml_xref_all_experiments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null,
    property varchar not null,
    reftype varchar not null,
    dblabel varchar not null,
    refvalue varchar not null
);

create table xml_xref_experiment_organisms (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null,
    taxid integer not null,
    primary key(source, filename, entry, experimentid)
);

create table xml_xref_experiment_pubmed (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, experimentid, refvalue)
);

create table xml_xref_experiment_methods (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null,
    property varchar not null,
    refvalue varchar not null,
    primary key(source, filename, entry, experimentid, property, refvalue)
);

create table xml_names_experiment_authors (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null,
    name varchar not null,
    primary key(source, filename, entry, experimentid, name)
);

create table xml_names_experiment_methods (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null,
    property varchar not null,
    name varchar not null,
    primary key(source, filename, entry, experimentid, property, name)
);
