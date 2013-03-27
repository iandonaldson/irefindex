begin;

create table irefweb_alias (
    id integer not null,
    version integer not null,
    alias varchar not null,
    name_space_id integer not null,
    primary key(id)
);

create table irefweb_geneid2rog (
    rgg integer not null,
    geneid integer not null,
    rog integer not null,
    rogid varchar not null,
    interactor_id integer not null,
    primary key(geneid, rog)
);

create table irefweb_name_space (
    id integer not null,
    version integer not null,
    name varchar not null,
    source_db_id integer not null,
    primary key(id)
);

create table irefweb_interaction (
    id integer not null,
    version integer not null,
    rig integer not null,
    rigid varchar not null,
    name varchar not null,
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
    description varchar not null,
    psi_mi_code varchar not null,
    primary key(id)
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
    primary_alias_id integer,
    used_alias_id integer not null,
    final_alias_id integer not null,
    canonical_alias_id integer not null,
    primary_taxonomy_id integer,
    used_taxonomy_id integer,
    final_taxonomy_id integer,
    position_as_found_in_source_db integer not null,
    score_id integer not null,
    canonical_score_id integer not null,
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
    pubmed_id varchar not null,
    interaction_detection_type_id integer,
    isSecondary integer not null,
    primary key(id)
);

create table irefweb_interaction_type (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar not null,
    psi_mi_code varchar not null,
    geneticInteraction integer not null,
    primary key(id)
);

create table irefweb_interactor (
    rog integer not null,
    rogid varchar not null,
    seguid varchar not null,
    taxonomy_id integer not null,
    interactor_type_id integer not null,
    display_interactor_alias_id integer not null,
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

create table irefweb_interactor_alias_display (
    rog integer not null,
    alias varchar not null,
    name_space_id integer not null,
    alias_id integer not null,
    interactor_id integer not null,
    interactor_alias_id integer not null,
    primary key(interactor_alias_id)
);

create table irefweb_interactor_detection_type (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar not null,
    psi_mi_code varchar not null,
    primary key(id)
);

create table irefweb_interactor_type (
    id integer not null,
    version integer not null,
    name varchar not null,
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
    "sequence" varchar not null,
    primary key(id)
);

create table irefweb_sequence_source_db (
    id integer not null,
    version integer not null,
    source_db_sqnc_id varchar not null,
    sequence_id integer not null,
    source_db_id integer not null,
    primary key(id)
);

create table irefweb_source_db (
    id integer not null,
    version integer not null,
    name varchar not null,
    release_date varchar,
    release_label varchar,
    comments varchar,
    primary key(id)
);

create table irefweb_statistics (
    sourcedb varchar not null,
    total varchar not null,
    PPI varchar not null,
    none_PPI varchar not null,
    with_RIGID varchar not null,
    no_RIGID varchar not null,
    PPI_without_RIGID varchar not null,
    percent_asign varchar not null,
    uniq_RIGID varchar not null,
    uniq_RIGID_perc varchar not null,
    uniq_canonical_RIGID varchar not null,
    uniq_canonical_RIGID_perc varchar not null
);

-- -----------------------------------------------------------------------------
-- Import tables.

\copy irefweb_alias                             from '<directory>/irefweb_alias'
\copy irefweb_geneid2rog                        from '<directory>/irefweb_geneid2rog'
\copy irefweb_interaction                       from '<directory>/irefweb_interaction'
\copy irefweb_interaction_detection_type        from '<directory>/irefweb_interaction_detection_type'
\copy irefweb_interaction_interactor            from '<directory>/irefweb_interaction_interactor'
\copy irefweb_interaction_interactor_assignment from '<directory>/irefweb_interaction_interactor_assignment'
\copy irefweb_interaction_source_db             from '<directory>/irefweb_interaction_source_db'
\copy irefweb_interaction_source_db_experiment  from '<directory>/irefweb_interaction_source_db_experiment'
\copy irefweb_interaction_type                  from '<directory>/irefweb_interaction_type'
\copy irefweb_interactor                        from '<directory>/irefweb_interactor'
\copy irefweb_interactor_alias                  from '<directory>/irefweb_interactor_alias'
\copy irefweb_interactor_alias_display          from '<directory>/irefweb_interactor_alias_display'
\copy irefweb_interactor_detection_type         from '<directory>/irefweb_interactor_detection_type'
\copy irefweb_interactor_type                   from '<directory>/irefweb_interactor_type'
\copy irefweb_name_space                        from '<directory>/irefweb_name_space'
\copy irefweb_score                             from '<directory>/irefweb_score'
\copy irefweb_sequence                          from '<directory>/irefweb_sequence'
\copy irefweb_sequence_source_db                from '<directory>/irefweb_sequence_source_db'
\copy irefweb_source_db                         from '<directory>/irefweb_source_db'
\copy irefweb_statistics                        from '<directory>/irefweb_statistics'

commit;
