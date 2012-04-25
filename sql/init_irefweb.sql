create table irefweb_alias (
    id integer not null,
    version integer not null,
    alias varchar not null,
    name_space_id integer not null,
    primary key(id)
);

create table irefweb_interaction (
    id integer not null,
    version integer not null,
    rig integer not null,
    rigid varchar not null,
    name varchar,
    description varchar,
    hpr integer,
    lpr integer,
    np integer,
    primary key(id)
);

create table irefweb_interaction_detection_type (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar,
    psi_mi_code varchar,
    primary key(id),
    unique(name)
);

create table irefweb_interaction_interactor (
    id integer not null,
    version integer not null,
    interaction_id integer not null,
    interactor_id integer not null,
    cardinality integer not null,
    primary key(id)
);

create table irefweb_interaction_interactor_assignment (
    id integer not null,
    version integer not null,
    interaction_interactor_id integer not null,
    interaction_source_db_id integer not null,
    interactor_detection_type_id integer,
    primary_alias_id integer not null,
    used_alias_id integer not null,
    final_alias_id integer not null,
    canonical_alias_id integer not null,
    primary_taxonomy_id integer not null,
    used_taxonomy_id integer not null,
    final_taxonomy_id integer not null,
    position_as_found_in_source_db integer not null,
    score_id integer not null,
    canonical_score_id integer,
    primary key(id)
);

create table irefweb_interaction_source_db (
    id integer not null,
    version integer not null,
    interaction_id integer not null,
    source_db_intrctn_id varchar,
    source_db_id integer not null,
    interaction_type_id integer,
    primary key(id)
);

create table irefweb_interaction_source_db_experiment (
    id integer not null,
    version integer not null,
    interaction_source_db_id integer not null,
    bait_interaction_interactor_id integer,
    pubmed_id integer not null,
    interaction_detection_type_id integer,
    isSecondary integer,
    primary key(id)
);

create table irefweb_interaction_type (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar,
    psi_mi_code varchar,
    isGeneticInteraction integer,
    primary key(id)
);

create table irefweb_interactor (
    rog integer,
    rogid varchar,
    seguid varchar,
    taxonomy_id integer,
    interactor_type_id integer,
    display_interactor_alias_id integer,
    sequence_id integer,
    id integer not null,
    version integer not null,
    primary key(id)
);

create table irefweb_interactor_alias (
    id integer not null,
    version integer not null,
    interactor_id integer not null,
    alias_id integer not null,
    primary key(id)
);

create table irefweb_interactor_detection_type (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar,
    psi_mi_code varchar,
    primary key(id)
);

create table irefweb_interactor_type (
    id integer not null,
    version integer not null,
    name varchar,
    primary key(id)
);

create table irefweb_name_space (
    id integer not null,
    version integer not null,
    name varchar not null,
    source_db_id integer,
    primary key(id)
);

create table irefweb_score (
    id integer not null,
    version integer not null,
    code varchar not null,
    description varchar not null,
    primary key(id)
);

create table irefweb_sequence (
    id integer not null,
    version integer not null,
    seguid varchar not null,
    sequence varchar,
    primary key(id),
    unique(seguid)
);

create table irefweb_sequence_source_db (
    id integer not null,
    version integer not null,
    source_db_sqnc_id integer not null,
    sequence_id integer not null,
    source_db_id integer not null,
    primary key(id)
);

create table irefweb_source_db (
    id integer not null,
    version integer not null,
    name varchar not null,
    release_date date not null,
    release_label varchar,
    comments varchar,
    primary key(id)
);

create table irefweb_statistics (
    sourcedb varchar,
    total integer,
    PPI integer,
    none_PPI integer,
    with_RIGID integer,
    no_RIGID integer,
    PPI_without_RIGID integer,
    percent_asign decimal,
    uniq_RIGID integer,
    uniq_RIGID_perc decimal,
    uniq_canonical_RIGID integer,
    uniq_canonical_RIGID_perc decimal
);

create table irefweb_geneid2rog (
    rgg integer not null,
    geneid integer,
    rog integer,
    rogid varchar,
    interactor_id integer
);
