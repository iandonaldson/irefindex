begin;

-- iRefWeb employs a schema with ubiquitous surrogate keys, some of which are
-- preserved across releases in the following tables:
--
-- interaction                  (integer RIG identifier)
-- interaction_detection_type   (iRefWeb-specific sequence number)
-- interaction_type             (iRefWeb-specific sequence number)
-- interactor                   (integer ROG identifier)
-- interactor_detection_type    (iRefWeb-specific sequence number)
-- interactor_type              (iRefWeb-specific sequence number)
-- name_space                   (iRefWeb-specific sequence number)
-- sequence                     (iRefWeb-specific sequence number)
-- source_db                    (iRefWeb-specific sequence number)
--
-- Other tables do not attempt to preserve the keys from one release to the
-- next (using iRefWeb-specific sequence numbers throughout):
--
-- alias
-- interaction_interactor
-- interactor_alias
-- interactor_alias_display

-- NOTE: To do:
-- NOTE: interaction_interactor_assignment
-- NOTE: interaction_source_db
-- NOTE: interaction_source_db_experiment
-- NOTE: score
-- NOTE: sequence_source_db
-- NOTE: statistics
-- NOTE: geneid2rog



-- Interactor names are defined here.

create temporary table tmp_uniprot_rogids as
    select sequence || taxid as rogid, uniprotid
    from uniprot_proteins
    where taxid is not null;

analyze tmp_uniprot_rogids;

-- Get a description of each interaction in terms of the distinct interactors.

create temporary table tmp_interaction_descriptions as

    -- Produce for each rigid a description of the form...
    -- 'only name|...' for single distinct interactors
    -- 'name|... and name|...' for two distinct interactors
    -- 'name|..., name|... and name|...' for many distinct interactors

    select rigid,
        case when n = 1 then 'only ' || allnames[1]
             when n = 2 then allnames[1] || ' and ' || allnames[2]
                        else array_to_string(allnames[1:n-1], ', ') || ' and ' || allnames[n]
        end as description
    from (
        select rigid, count(distinct rogid) as n, array_accum(names) as allnames
        from (
            select rigid, I.rogid, array_to_string(array_accum(distinct coalesce(U.uniprotid, I.rogid)), '|') as names
            from irefindex_distinct_interactions as I
            left outer join tmp_uniprot_rogids as U
                on I.rogid = U.rogid
            group by rigid, I.rogid
            ) as X
        group by rigid
        ) as Y;

analyze tmp_interaction_descriptions;



-- Get old interactions.

create temporary table tmp_previous_interactions (
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

\copy tmp_previous_interactions from '<directory>/old_irefweb_interaction'

analyze tmp_previous_interactions;

-- Define the current version using a sequence.

create temporary sequence tmp_version minvalue 0;

select setval('tmp_version', (select coalesce(max(version), 0) from tmp_previous_interactions));

-- Combine previously unknown interactions with the previous table.

create temporary table tmp_irefweb_interactions as
    select
        I.rig as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        I.rig as rig,
        R.rigid,
        'Interaction involving ' || D.description as name,
        cast(null as varchar) as description,
        H.score as hpr,
        L.score as lpr,
        N.score as np

    -- Start with the active interactions.

    from irefindex_rigids as R
    inner join irefindex_rig2rigid as I
        on R.rigid = I.rigid
    inner join tmp_interaction_descriptions as D
        on R.rigid = D.rigid

    -- Add interaction score information.

    left outer join irefindex_confidence as H
        on R.rigid = H.rigid
        and H.scoretype = 'hpr'
    left outer join irefindex_confidence as L
        on R.rigid = L.rigid
        and L.scoretype = 'lpr'
    left outer join irefindex_confidence as N
        on R.rigid = N.rigid
        and N.scoretype = 'np'

    -- Exclude previous interactions.

    left outer join tmp_previous_interactions as P
        on I.rig = P.rig
    where P.rig is null
    group by R.rigid, I.rig, D.description, H.score, L.score, N.score

    -- Combine with previous interactions.

    union all
    select id, version, rig, rigid, name, description, hpr, lpr, np
    from tmp_previous_interactions;

\copy tmp_irefweb_interactions to '<directory>/irefweb_interaction'



-- Get old interactor detection types.

create temporary table tmp_previous_interactor_detection_types (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar not null,
    psi_mi_code varchar not null,
    primary key(id)
);

\copy tmp_previous_interactor_detection_types from '<directory>/irefweb_interactor_detection_type'

analyze tmp_previous_interactor_detection_types;

-- Combine previously unknown interactor detection types with the previous table.

create temporary sequence tmp_irefweb_interactor_detection_types_id minvalue 0;

select setval('tmp_irefweb_interactor_detection_types_id', coalesce(max(id), 0))
from tmp_previous_interactor_detection_types;

-- NOTE: Feature detection methods are not present here.

create temporary table tmp_irefweb_interactor_detection_types as
    select
        nextval('tmp_irefweb_interactor_detection_types_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        coalesce(min(S.name), T.name) as name,
        'interactor detection method - ' || T.name as description,
        T.code as psi_mi_code
    from xml_xref_participants as X
    inner join psicv_terms as T
        on X.refvalue = T.code
        and T.nametype = 'preferred'
    left outer join psicv_terms as S
        on X.refvalue = S.code
        and S.nametype = 'synonym'
        and S.qualifier = 'PSI-MI-short'

    -- Exclude previous interactor detection types.

    left outer join tmp_previous_interactor_detection_types as P
        on T.code = P.psi_mi_code
    where P.psi_mi_code is null
        and X.property = 'participantIdentificationMethod'
    group by T.name, T.code

    -- Combine with previous interactor detection types.

    union all
    select id, version, name, description, psi_mi_code
    from tmp_previous_interactor_detection_types;

\copy tmp_irefweb_interactor_detection_types to '<directory>/irefweb_interactor_detection_type'



-- Get old interaction detection types.

create temporary table tmp_previous_interaction_detection_types (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar not null,
    psi_mi_code varchar not null,
    primary key(id)
);

\copy tmp_previous_interaction_detection_types from '<directory>/irefweb_interaction_detection_type'

analyze tmp_previous_interaction_detection_types;

-- Combine previously unknown interaction detection types with the previous table.

create temporary sequence tmp_irefweb_interaction_detection_types_id minvalue 0;

select setval('tmp_irefweb_interaction_detection_types_id', coalesce(max(id), 0))
from tmp_previous_interaction_detection_types;

-- NOTE: Feature detection methods are not present here.

create temporary table tmp_irefweb_interaction_detection_types as
    select
        nextval('tmp_irefweb_interaction_detection_types_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        coalesce(min(S.name), T.name) as name,
        'interaction detection method - ' || T.name as description,
        T.code as psi_mi_code
    from xml_xref_experiment_methods as E
    inner join psicv_terms as T
        on E.refvalue = T.code
        and T.nametype = 'preferred'
    left outer join psicv_terms as S
        on E.refvalue = S.code
        and S.nametype = 'synonym'
        and S.qualifier = 'PSI-MI-short'

    -- Exclude previous interaction detection types.

    left outer join tmp_previous_interaction_detection_types as P
        on T.code = P.psi_mi_code
    where P.psi_mi_code is null
        and E.property = 'interactionDetectionMethod'
    group by T.name, T.code

    -- Combine with previous interaction detection types.

    union all
    select id, version, name, description, psi_mi_code
    from tmp_previous_interaction_detection_types;

\copy tmp_irefweb_interaction_detection_types to '<directory>/irefweb_interaction_detection_type'



-- Get old interaction types.

create temporary table tmp_previous_interaction_types (
    id integer not null,
    version integer not null,
    name varchar not null,
    description varchar,
    psi_mi_code varchar,
    isGeneticInteraction integer, -- in (-1, 0, 1)
    primary key(id)
);

\copy tmp_previous_interaction_types from '<directory>/old_irefweb_interaction_type'

analyze tmp_previous_interaction_types;

-- Combine previously unknown interaction types with the previous table.

create temporary sequence tmp_irefweb_interaction_types_id minvalue 0;

select setval('tmp_irefweb_interaction_types_id', coalesce(max(id), 0))
from tmp_previous_interaction_types;

create temporary table tmp_irefweb_interaction_types as
    select
        nextval('tmp_irefweb_interaction_types_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        coalesce(min(S.name), T.name) as name,
        'interaction type - ' || T.name as description,
        T.code as psi_mi_code,
        case when T.code = 'MI:0000' then -1
             when G.code is null then 0
             else 1
        end as geneticInteraction
    from xml_xref_interaction_types as I
    inner join psicv_terms as T
        on I.refvalue = T.code
        and T.nametype = 'preferred'
    left outer join psicv_terms as S
        on I.refvalue = S.code
        and S.nametype = 'synonym'
        and S.qualifier = 'PSI-MI-short'

    -- Matching the name appears to be equivalent to finding "descendants" of MI:0208.

    left outer join psicv_terms as G
        on T.code = G.code
        and G.nametype = 'preferred'
        and G.name like '%genetic interaction%'

    -- Exclude previous interaction types.

    left outer join tmp_previous_interaction_types as P
        on T.code = P.psi_mi_code
    where P.psi_mi_code is null
    group by T.name, T.code, G.code

    -- Combine with previous interaction types.

    union all
    select id, version, name, description, psi_mi_code, isGeneticInteraction
    from tmp_previous_interaction_types;

\copy tmp_irefweb_interaction_types to '<directory>/irefweb_interaction_type'



-- Get old source databases.

create temporary table tmp_previous_source_databases (
    id integer not null,
    version integer not null,
    name varchar not null,
    release_date date not null,
    release_label varchar,
    comments varchar,
    primary key(id)
);

\copy tmp_previous_source_databases from '<directory>/old_irefweb_source_db'

analyze tmp_previous_source_databases;

-- Get current source databases.

create temporary table tmp_current_source_databases as

    -- Get all databases represented by interactors.

    select distinct
        I.dblabel as name,
        M.releasedate as release_date,
        M.version as release_label,
        M.downloadfiles as comments
    from xml_xref_all_interactors as I
    left outer join irefindex_manifest as M
        on I.dblabel = lower(M.source)

    -- Get all other source databases.

    union all
    select distinct
        lower(M.source) as name,
        M.releasedate as release_date,
        M.version as release_label,
        M.downloadfiles as comments
    from irefindex_manifest as M
    left outer join xml_xref_all_interactors as I
        on lower(M.source) = I.dblabel
    where I.dblabel is null;

analyze tmp_current_source_databases;

-- Combine previously unknown source databases with the previous table.

create temporary sequence tmp_irefweb_source_databases_id minvalue 0;

select setval('tmp_irefweb_source_databases_id', coalesce(max(id), 0))
from tmp_previous_source_databases;

create temporary table tmp_irefweb_source_databases as
    select
        nextval('tmp_irefweb_source_databases_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        C.name,
        C.release_date,
        C.release_label,
        C.comments
    from tmp_current_source_databases as C

    -- Exclude previous source databases.

    left outer join tmp_previous_source_databases as P
        on C.name = P.name
    where P.name is null

    -- Combine with previous source databases.

    union all
    select id, version, name, release_date, release_label, comments
    from tmp_previous_source_databases;

analyze tmp_irefweb_source_databases;

\copy tmp_irefweb_source_databases to '<directory>/irefweb_source_db'



-- Name spaces are more or less database labels.

-- Get old name spaces.

create temporary table tmp_previous_name_spaces (
    id integer not null,
    version integer not null,
    name varchar not null,
    source_db_id integer not null,
    primary key(id)
);

\copy tmp_previous_name_spaces from '<directory>/old_irefweb_name_space'

-- Combine previously unknown name spaces with the previous table.

create temporary sequence tmp_irefweb_name_spaces_id minvalue 0;

select setval('tmp_irefweb_name_spaces_id', coalesce(max(id), 0))
from tmp_previous_name_spaces;

create temporary table tmp_irefweb_name_spaces as
    select
        nextval('tmp_irefweb_name_spaces_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        S.name,
        S.id as source_db_id
    from tmp_irefweb_source_databases as S

    -- Exclude previous name spaces.

    left outer join tmp_previous_name_spaces as P
        on S.name = P.name
    where P.name is null

    -- Combine with previous name spaces.

    union all
    select id, version, name, source_db_id
    from tmp_previous_name_spaces;

\copy tmp_irefweb_name_spaces to '<directory>/irefweb_name_space'



-- Interactor details providing interactor type and alias information.
-- This table maps each interactor to a single type and to many aliases.

create temporary table tmp_interactors as
    select distinct

        -- Interactor information.

        I.rog as rog,
        C.rogid as rogid,
        substring(C.rogid for 28) as seguid,
        R.taxid as taxonomy_id,

        -- Alias information.

        A.refvalue as alias,
        N.id as name_space_id,

        -- Interactor type information.

        V.name as name

    -- Interactor information.

    from irefindex_rogids as R
    inner join irefindex_rogids_canonical as C
        on R.rogid = C.rogid
    inner join irefindex_rog2rogid as I
        on C.rogid = I.rogid

    -- Interactor type information.

    inner join xml_xref_interactor_types as T
        on (R.source, R.filename, R.entry, R.interactorid)
         = (T.source, T.filename, T.entry, T.interactorid)
    inner join psicv_terms as V
        on T.refvalue = V.code

    -- Alias information.

    inner join xml_xref_all_interactors as A
        on (R.source, R.filename, R.entry, R.interactorid)
         = (A.source, A.filename, A.entry, A.interactorid)
    inner join tmp_irefweb_name_spaces as N
        on A.dblabel = N.name;

analyze tmp_interactors;



-- The interactor types table is just a list of the different interactor types
-- known to iRefIndex.

-- Get old interactor types.

create temporary table tmp_previous_interactor_types (
    id integer not null,
    version integer not null,
    name varchar not null,
    primary key(id)
);

\copy tmp_previous_interactor_types from '<directory>/old_irefweb_interactor_types'

analyze tmp_previous_interactor_types;

-- Get current interactor types.

create temporary table tmp_current_interactor_types as
    select distinct name
    from tmp_interactors as I;

analyze tmp_current_interactor_types;

-- Use a sequence to number previously unknown interactor types.

create temporary sequence tmp_irefweb_interactor_types_id minvalue 0;

select setval('tmp_irefweb_interactor_types_id', coalesce(max(id), 0))
from tmp_previous_interactor_types;

-- Combine previously unknown interactor types with the previous table.

create temporary table tmp_irefweb_interactor_types as
    select
        nextval('tmp_irefweb_interactor_types_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        C.name as name
    from tmp_current_interactor_types as C

    -- Exclude previous interactor types.

    left outer join tmp_previous_interactor_types as P
        on C.name = P.name
    where P.name is null

    -- Combine with previous interactor types.

    union all
    select id, version, name
    from tmp_previous_interactor_types;

\copy tmp_irefweb_interactor_types to '<directory>/irefweb_interactor_type'



-- Aliases reside in a separate table.

create temporary sequence tmp_irefweb_alias_id;

create temporary table tmp_irefweb_aliases as
    select
        nextval('tmp_irefweb_alias_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        alias,
        name_space_id
    from tmp_interactors as I
    group by alias, name_space_id;

create index tmp_irefweb_aliases_index on tmp_irefweb_aliases(alias, name_space_id);

analyze tmp_irefweb_aliases;

\copy tmp_irefweb_aliases to '<directory>/irefweb_alias'



-- Interactor aliases map interactors to aliases.
-- The surrogate key needs to be obtained from the generated aliases table.

create temporary sequence tmp_irefweb_interactor_aliases_id;

create temporary table tmp_irefweb_interactor_aliases as
    select nextval('tmp_irefweb_interactor_aliases_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        I.rog as interactor_id,
        A.id as alias_id
    from tmp_interactors as I
    inner join tmp_irefweb_aliases as A
        on I.alias = A.alias
        and I.name_space_id = A.name_space_id;

create index tmp_irefweb_interactor_aliases_index on tmp_irefweb_interactor_aliases(interactor_id);

analyze tmp_irefweb_interactor_aliases;

\copy tmp_irefweb_interactor_aliases to '<directory>/irefweb_interactor_alias'



-- Get old sequence information.

create temporary table tmp_previous_sequences (
    id integer not null,
    version integer not null,
    seguid varchar not null,
    sequence varchar not null,
    primary key(id)
);

\copy tmp_previous_sequences from '<directory>/old_irefweb_sequence'

-- Get current sequences.

create temporary table tmp_current_sequences as
    select "sequence", actualsequence
    from uniprot_sequences
    union
    select "sequence", actualsequence
    from refseq_sequences
    union
    select "sequence", actualsequence
    from ipi_sequences
    union
    select "sequence", actualsequence
    from genpept_sequences
    union
    select "sequence", actualsequence
    from pdb_sequences;

create index tmp_current_sequences_index on tmp_current_sequences(actualsequence);
analyze tmp_current_sequences;

-- Use a sequence to number previously unknown sequences.

create temporary sequence tmp_irefweb_sequences_id;

select setval('tmp_irefweb_sequences_id', coalesce(max(id), 0))
from tmp_previous_sequences;

create temporary table tmp_irefweb_sequences as
    select nextval('tmp_irefweb_sequences_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        "sequence" as seguid,
        actualsequence as "sequence"
    from tmp_current_sequences as S

    -- Exclude previous sequences.

    left outer join tmp_previous_sequences as P
        on S.sequence = P.sequence

    -- Combine with previous sequences.

    union all
    select id, version, seguid, "sequence"
    from tmp_previous_sequences;

\copy tmp_irefweb_sequences to '<directory>/irefweb_sequence'



-- Get old interactors.

create temporary table tmp_previous_interactors (
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

\copy tmp_previous_interactors from '<directory>/old_irefweb_interactors'

analyze tmp_previous_interactors;

-- Combine previously unknown interactors with the previous table.

create temporary table tmp_irefweb_interactors as
    select
        rog,
        rogid,
        seguid,
        taxonomy_id,
        T.id as interactor_type,
        A.id as display_interactor_alias_id,
        S.id as sequence_id,
        rog as id,
        setval('tmp_version', nextval('tmp_version'), false) as version
    from tmp_interactors as I
    inner join tmp_irefweb_interactor_types as T
        on I.name = T.name
    inner join tmp_irefweb_interactor_aliases as A
        on I.rog = A.interactor_id
    inner join tmp_irefweb_sequences as S
        on substring(I.rogid for 28) = S.seguid;

analyze tmp_irefweb_interactors;

\copy tmp_irefweb_interactors to '<directory>/irefweb_interactor'



-- Create a mapping from canonical interactions to canonical interactors.

create temporary sequence tmp_irefweb_interaction_interactors_id;

create temporary table tmp_irefweb_interaction_interactors as
    select
        nextval('tmp_irefweb_interaction_interactors_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        rig as interaction_id,
        rog as interactor_id,
        count(CO.rogid) as cardinality
    from irefindex_distinct_interactions as I
    inner join irefindex_rigids_canonical as CI
        on I.rigid = CI.rigid
    inner join irefindex_rogids_canonical as CO
        on I.rogid = CO.rogid
    inner join irefindex_rig2rigid as II
        on CI.crigid = II.rigid
    inner join irefindex_rog2rogid as IO
        on CO.crogid = IO.rogid
    group by rig, rog;

\copy tmp_irefweb_interaction_interactors as '<directory>/irefweb_interaction_interactor'



-- Create a record of specific interactions (interactions with source
-- information).

create temporary sequence tmp_irefweb_interaction_sources_id;

create temporary table tmp_irefweb_interaction_sources as
    select
        nextval('tmp_irefweb_interaction_sources_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        II.id as interaction_id,
        N.refvalue as source_db_intrctn_id,
        D.id as source_db_id,
        IT.id as interaction_type_id
    from irefindex_rigids as R
    inner join irefindex_rig2rigid as I
        on R.rigid = I.rigid
    inner join tmp_irefweb_interactions as II
        on I.rig = II.id
    inner join xml_xref_interactions as N
        on (R.source, R.filename, R.entry, R.interactionid)
         = (N.source, N.filename, N.entry, N.interactionid)
    inner join tmp_irefweb_source_databases as D
        on N.dblabel = D.name
    left outer join xml_xref_interaction_types as T
        on (R.source, R.filename, R.entry, R.interactionid)
         = (T.source, T.filename, T.entry, T.interactionid)
    left outer join tmp_irefweb_interaction_types as IT
        on T.refvalue = IT.psi_mi_code;



rollback;
