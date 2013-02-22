begin;

-- iRefWeb employs a schema with ubiquitous surrogate keys, some of which are
-- preserved across releases in the following tables:
--
-- interaction                      (integer RIG identifier)
-- interaction_detection_type       (iRefWeb-specific sequence number)
-- interaction_source_db            (iRefWeb-specific sequence number)
-- interaction_source_db_experiment (iRefWeb-specific sequence number)
-- interaction_type                 (iRefWeb-specific sequence number)
-- interaction_interactor           (iRefWeb-specific sequence number)
-- interactor                       (integer ROG identifier)
-- interactor_detection_type        (iRefWeb-specific sequence number)
-- interactor_type                  (iRefWeb-specific sequence number)
-- name_space                       (iRefWeb-specific sequence number)
-- score                            (iRefWeb-specific sequence number)
-- sequence                         (iRefWeb-specific sequence number)
-- NOTE: To do: sequence_source_db
-- source_db                        (iRefWeb-specific sequence number)
--
-- Other tables do not attempt to preserve the keys from one release to the
-- next (using iRefWeb-specific sequence numbers throughout):
--
-- alias
-- NOTE: To do: geneid2rog
-- interactor_alias
-- interactor_alias_display
-- NOTE: To do: interaction_interactor_assignment
-- NOTE: To do: statistics



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

-- Get participant positions.

create temporary table tmp_participant_positions as
    select source, filename, entry, interactionid, "index", interactors["index"] as interactorid
    from (
        select source, filename, entry, interactionid, generate_subscripts(interactors, 1) as "index", interactors
        from (
            select source, filename, entry, interactionid, array_accum(interactorid) as interactors
            from (
                select source, filename, entry, interactionid, interactorid, participantid
                from xml_interactors
                order by source, filename, entry, interactionid, participantid
                ) as X
            group by source, filename, entry, interactionid
            ) as Y
        ) as Z;

analyze tmp_participant_positions;



-- Interactions are records mapping RIG identifiers to general interaction
-- details including the confidence scores and a textual description (produced
-- above).

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



-- Interactor detection types are collected from interaction participant
-- information and enumerated.

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



-- Interaction detection types are collected from interaction experiment
-- information and enumerated.

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



-- Interaction types are collected from interaction information and enumerated.

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



-- Source databases are collected from the manifest information (provided by the
-- downloaded data files) and from interactor information (indicating the origin
-- of data).

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



-- Name spaces are more or less database labels, although it seems that data
-- types such as "short label", "full name", "alias" (and so on) are also
-- present.

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
-- This table maps each interactor to a single type and to a single set of
-- aliases, using the "name space" identifiers instead of database labels.

create temporary table tmp_interactors as
    select

        -- Specific interactor information.

        R.source, R.filename, R.entry, R.interactorid,

        -- Interactor information.

        I.rog as rog,
        C.crogid as rogid,
        substring(C.rogid for 28) as seguid,

        -- Taxonomy information.

        R.taxid as taxonomy_id,
        X.originaltaxid as used_taxonomy_id,
        O.taxid as primary_taxonomy_id,

        -- Interactor type information.

        V.name as name,

        -- Alias information.

        originalN.id as used_name_space_id,
        X.originalrefvalue as used_alias,
        finalN.id as final_name_space_id,
        X.finalrefvalue as final_alias,
        primaryN.id as primary_name_space_id,
        primaryA.refvalue as primary_alias,
        canonicalN.id as canonical_name_space_id,
        canonicalA.refvalue as canonical_alias,

        -- Assignment score information.

        XS.score

    -- Interactor information.

    from irefindex_rogids as R
    inner join irefindex_rogids_canonical as C
        on R.rogid = C.rogid
    inner join irefindex_rog2rogid as I
        on C.crogid = I.rogid

    -- Interactor type information.

    inner join xml_xref_interactor_types as T
        on (R.source, R.filename, R.entry, R.interactorid)
         = (T.source, T.filename, T.entry, T.interactorid)
    inner join psicv_terms as V
        on T.refvalue = V.code

    -- Alias information.

    inner join irefindex_assignments as X
        on (R.source, R.filename, R.entry, R.interactorid)
         = (X.source, X.filename, X.entry, X.interactorid)
    inner join tmp_irefweb_name_spaces as originalN
        on X.originaldblabel = originalN.name
    inner join tmp_irefweb_name_spaces as finalN
        on X.finaldblabel = finalN.name

    -- Assignment score information.

    inner join irefindex_assignment_scores as XS
        on (R.source, R.filename, R.entry, R.interactorid)
         = (XS.source, XS.filename, XS.entry, XS.interactorid)

    -- Primary alias information.

    inner join xml_xref_all_interactors as primaryA
        on (R.source, R.filename, R.entry, R.interactorid)
         = (primaryA.source, primaryA.filename, primaryA.entry, primaryA.interactorid)
    inner join tmp_irefweb_name_spaces as primaryN
        on primaryA.dblabel = primaryN.name
        and primaryA.reftype = 'primaryRef'

    -- Primary taxonomy information.

    left outer join xml_organisms as O
        on (X.source, X.filename, X.entry, X.interactorid)
         = (O.source, O.filename, O.entry, O.parentid)
        and O.scope = 'interactor'

    -- Canonical alias information.

    inner join irefindex_rogid_identifiers_preferred as canonicalA
        on C.crogid = canonicalA.rogid
    inner join tmp_irefweb_name_spaces as canonicalN
        on canonicalA.dblabel = canonicalN.name;

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



-- Aliases are an aggregation of different name information with an arbitrary
-- sequence number assigned to each one.

create temporary sequence tmp_irefweb_alias_id;

create temporary table tmp_irefweb_aliases as
    select
        nextval('tmp_irefweb_alias_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        alias,
        name_space_id
    from (
        select distinct alias, name_space_id
        from tmp_interactors
        union
        select distinct final_alias as alias, final_name_space_id as name_space_id
        from tmp_interactors
        union
        select distinct primary_alias as alias, primary_name_space_id as name_space_id
        from tmp_interactors
        ) as X
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



-- Sequences are collected from the original sequence data and enumerated.

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



-- Interactors are records mapping ROG identifiers to general interactor
-- details including sequence and alias information.

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

-- Get old mappings.

create temporary table tmp_previous_interaction_interactors (
    id integer not null,
    version integer not null,
    rig integer not null,
    rog integer not null,
    cardinality integer not null,
    primary key(id)
);

\copy tmp_previous_interaction_interactors from '<directory>/old_irefweb_interaction_interactor'

-- Combine previously unknown mappings with the previous table.

create temporary sequence tmp_irefweb_interaction_interactors_id;

create temporary table tmp_irefweb_interaction_interactors as
    select
        nextval('tmp_irefweb_interaction_interactors_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        CI.rig as interaction_id,
        CO.rog as interactor_id,
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

    -- Exclude previous mappings.

    left outer join tmp_previous_interaction_interactors as P
        on CI.rig = P.rig
        and CO.rog = P.rog
    where P.rig is null
    group by rig, rog

    -- Combine with previous mappings.

    union
    select id, version, interaction_id, interactor_id, cardinality
    from tmp_previous_interaction_interactors;

\copy tmp_irefweb_interaction_interactors as '<directory>/irefweb_interaction_interactor'



-- Create a record of specific interactions (interactions with source
-- information).

-- Get old source interactions.

create temporary table tmp_old_interaction_sources (
    id integer not null,
    version integer not null,
    interaction_id integer not null,
    source_db_intrctn_id integer not null,
    source_db_id integer not null,
    interaction_type_id integer not null,
    primary key(id)
);

\copy tmp_old_interaction_sources from '<directory>/old_irefweb_interaction_source_db'

-- Combine previously unknown source interactions with the previous table.

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
        on T.refvalue = IT.psi_mi_code

    -- Exclude previous source interactions.

    left outer join tmp_old_interaction_sources as P
        on N.refvalue = P.source_db_intrctn_id
        and D.id = P.source_db_id
        and IT.id = P.interaction_type_id

    where P.source_db_intrctn_id is null

    -- Combine with previous source interactions.

    union
    select id, version, interaction_id, source_db_intrctn_id, source_db_id, interaction_type_id
    from tmp_old_interaction_sources;

\copy tmp_irefweb_interaction_sources to '<directory>/irefweb_interaction_source_db'



-- The scores table is a list of distinct assignment scores.
-- NOTE: The description always seems to be an empty string.

-- Get old scores.

create temporary table tmp_previous_scores (
    id integer not null,
    version integer not null,
    code varchar not null,
    description varchar not null,
    primary key(id)
);

\copy tmp_previous_scores from '<directory>/old_irefweb_score'

-- Combine previously unknown scores with the previous table.

create temporary sequence tmp_irefweb_scores_id;

create temporary table tmp_irefweb_scores as
    select distinct
        nextval('tmp_irefweb_scores_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        score as code,
        cast('' as varchar) as description
    from irefindex_assignment_scores as S

    -- Exclude previous scores.

    left outer join tmp_previous scores as P
        on S.score = P.code
    where P.code is null

    -- Combine with previous scores.

    union
    select id, version, code, description
    from tmp_irefweb_scores;

\copy tmp_irefweb_scores to '<directory>/irefweb_score'



-- Collect scores for canonical interactors. Since scoring is related to
-- specific interactors and not general interactors, the "best" score is chosen
-- for each canonical interactor.

create temporary table tmp_score_values as
    select score,
        case when score like '%P%' then 1 else 0 end +
        case when score like '%S%' then 2 else 0 end +
        case when score like '%U%' then 4 else 0 end +
        case when score like '%V%' then 8 else 0 end +
        case when score like '%T%' then 16 else 0 end +
        case when score like '%G%' then 32 else 0 end +
        case when score like '%D%' then 64 else 0 end +
        case when score like '%M%' then 128 else 0 end +
        case when score like '%+%' then 256 else 0 end +
        case when score like '%O%' then 512 else 0 end +
        case when score like '%X%' then 1024 else 0 end +
        case when score like '%L%' then 4096 else 0 end +
        case when score like '%I%' then 8192 else 0 end +
        case when score like '%E%' then 16384 else 0 end +
        case when score like '%Y%' then 32768 else 0 end +
        case when score like '%N%' then 65536 else 0 end +
        case when score like '%Q%' then 131072 else 0 end as value
    from tmp_irefweb_scores;

analyze tmp_irefweb_scores;

create temporary table tmp_canonical_scores as
    select rogid, score
    from (
        select C.crogid as rogid, min(value) as value
        from irefindex_rogids_canonical as C
        inner join irefindex_rogids as R
            on C.crogid = R.rogid
        inner join irefindex_assignment_scores as A
            on (R.source, R.filename, R.entry, R.interactorid)
             = (A.source, A.filename, A.entry, A.interactorid)
        inner join tmp_score_values as S
            on A.score = S.score
        group by C.crogid
        ) as X
    inner join tmp_score_values as S
        on X.value = S.value;

analyze tmp_canonical_scores;



-- NOTE: interaction_source_db_experiment is specific interaction+interactor of
-- NOTE: bait, interaction detection type, PubMed reference.



-- Create a record of assignments.

create temporary sequence tmp_irefweb_assignments_id;

create temporary table tmp_irefweb_assignments as
    select
        nextval('tmp_irefweb_assignments_id') as id,
        setval('tmp_version', nextval('tmp_version'), false) as version,
        II.id as interaction_interactor_id,
        S.id as interaction_source_db_id,
        IDT.id as interactor_detection_type_id,
        primaryA.id as primary_alias_id,
        usedA.id as used_alias_id,
        finalA.id as final_alias_id,
        canonicalA.id as canonical_alias_id,
        primary_taxonomy_id,
        used_taxonomy_id,
        final_taxonomy_id,
        "index" as position_as_found_in_source_db,
        scores.id as score_id,
        scoresC.id as canonical_score_id
    from tmp_irefweb_interaction_interactors as II
    inner join tmp_irefweb_interaction_sources as S
        on II.interaction_id = S.interaction_id

    -- Experimental details.

    inner join irefindex_rig2rigid as RI
        on II.interactionid = RI.rig
    inner join irefindex_rigids as R
        on RI.rigid = R.rigid
    inner join xml_experiments as E
        on (R.source, R.filename, R.entry, R.interactionid)
         = (E.source, E.filename, E.entry, E.interactionid)
    inner join xml_xref_experiment_methods as EM
        on (E.source, E.filename, E.entry, E.experimentid)
         = (EM.source, EM.filename, EM.entry, EM.experimentid)
    inner join tmp_irefweb_interaction_detection_types as IDT
        on EM.code = IDT.code

    -- Interactor and assignment details.

    inner join tmp_interactors as I
        on (R.source, R.filename, R.entry, R.interactionid)
         = (I.source, I.filename, I.entry, I.interactionid)

    -- Alias details.

    inner join tmp_irefweb_aliases as usedA
        on I.alias = usedA.alias
        and I.name_space_id = usedA.name_space_id
    inner join tmp_irefweb_aliases as finalA
        on I.final_alias = finalA.alias
        and I.final_name_space_id = finalA.name_space_id
    inner join tmp_irefweb_aliases as primaryA
        on I.primary_alias = primaryA.alias
        and I.primary_name_space_id = primaryA.name_space_id
    inner join tmp_irefweb_aliases as canonicalA
        on I.canonical_alias = canonicalA.alias
        and I.canonical_name_space_id = canonicalA.name_space_id

    -- Assignment score details.

    inner join tmp_irefweb_scores as scores
        on I.score = scores.score

    -- Canonical score details.

    inner join tmp_canonical_scores as CS
        on I.rogid = CS.rogid
    inner join tmp_irefweb_scores as scoresC
        on CS.score = scoresC.score

    -- Participant details.

    inner join tmp_participant_positions as positions
        on (R.source, R.filename, R.entry, R.interactionid, I.interactorid)
         = (positions.source, positions.filename, positions.entry, positions.interactionid, positions.interactorid);



rollback;
