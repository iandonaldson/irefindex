begin;

-- Export iRefWeb tables to files in the data directory.

-- iRefWeb employs a schema with ubiquitous surrogate keys, preserved across
-- releases in the following tables:

-- interaction                       (integer RIG identifier)
-- interaction_detection_type        (iRefWeb-specific sequence number)
-- interaction_interactor            (iRefWeb-specific sequence number)
-- interaction_interactor_assignment (iRefWeb-specific sequence number)
-- interaction_source_db             (iRefWeb-specific sequence number)
-- interaction_source_db_experiment  (iRefWeb-specific sequence number)
-- interaction_type                  (iRefWeb-specific sequence number)
-- interactor                        (integer ROG identifier)
-- interactor_detection_type         (iRefWeb-specific sequence number)
-- interactor_type                   (iRefWeb-specific sequence number)
-- name_space                        (iRefWeb-specific sequence number)
-- score                             (iRefWeb-specific sequence number)
-- sequence                          (iRefWeb-specific sequence number)
-- sequence_source_db                (iRefWeb-specific sequence number)
-- source_db                         (iRefWeb-specific sequence number)

-- Other tables do not attempt to preserve the keys from one release to the
-- next (using iRefWeb-specific sequence numbers throughout):

-- alias
-- geneid2rog
-- interactor_alias
-- interactor_alias_display
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
            from irefindex_distinct_interactions_canonical as I
            left outer join tmp_uniprot_rogids as U
                on I.rogid = U.rogid
            group by rigid, I.rogid
            ) as X
        group by rigid
        ) as Y;

analyze tmp_interaction_descriptions;

-- Get participant positions.

create temporary table tmp_participant_positions as
    select source, filename, entry, interactionid, "index", interactors["index"][1] as interactorid, interactors["index"][2] as participantid
    from (
        select source, filename, entry, interactionid, generate_subscripts(interactors, 1) as "index", interactors
        from (
            select source, filename, entry, interactionid, array_array_accum(array[[interactorid, participantid]]) as interactors
            from (
                select source, filename, entry, interactionid, interactorid, participantid
                from xml_interactors
                order by source, filename, entry, interactionid, participantid
                ) as X
            group by source, filename, entry, interactionid
            ) as Y
        ) as Z;

analyze tmp_participant_positions;

-- Get interaction bait details.
-- NOTE: A relatively small number of interactions may specify multiple bait
-- NOTE: interactors, and in such cases, the first of these is chosen.

create temporary table tmp_baits as
    select I.source, I.filename, I.entry, I.interactionid, min(I.interactorid) as interactorid
    from xml_interactors as I
    inner join xml_xref_participants as roleP
        on (I.source, I.filename, I.entry, I.participantid)
         = (roleP.source, roleP.filename, roleP.entry, roleP.participantid)
        and roleP.property = 'experimentalRole'
        and roleP.refvalue = 'MI:0496' -- bait
    group by I.source, I.filename, I.entry, I.interactionid;

analyze tmp_baits;

-- Map specific interactors with general canonical interactors.

create temporary table tmp_bait_interactors as
    select X.source, X.filename, X.entry, X.interactionid, X.interactorid, rog as interactor_id
    from tmp_baits as X
    inner join irefindex_rogids as R
        on (X.source, X.filename, X.entry, X.interactorid)
         = (R.source, R.filename, R.entry, R.interactorid)
    inner join irefindex_rogids_canonical as C
        on R.rogid = C.rogid
    inner join irefindex_rog2rogid as CI
        on C.crogid = CI.rogid;

create index tmp_bait_interactors_index on tmp_bait_interactors(source, filename, entry, interactionid);

analyze tmp_bait_interactors;



-- Interactions are records mapping RIG identifiers to general interaction
-- details including the confidence scores and a textual description (produced
-- above). The RIG identifiers are canonical.

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

update tmp_previous_interactions set description = null where description = 'NULL';
update tmp_previous_interactions set name = null where name = '-';

analyze tmp_previous_interactions;

-- Combine previously unknown interactions with the previous table.

create temporary table tmp_irefweb_interactions as
    select
        I.rig as id,
        (select max(version) + 1 from tmp_previous_interactions) as version,
        I.rig as rig,
        C.crigid as rigid,
        'Interaction involving ' || D.description as name,
        cast(null as varchar) as description,
        H.score as hpr,
        L.score as lpr,
        N.score as np

    -- Start with the active interactions.

    from irefindex_rigids_canonical as C
    inner join irefindex_rig2rigid as I
        on C.crigid = I.rigid
    inner join tmp_interaction_descriptions as D
        on C.crigid = D.rigid

    -- Add interaction score information.

    left outer join irefindex_confidence as H
        on C.crigid = H.rigid
        and H.scoretype = 'hpr'
    left outer join irefindex_confidence as L
        on C.crigid = L.rigid
        and L.scoretype = 'lpr'
    left outer join irefindex_confidence as N
        on C.crigid = N.rigid
        and N.scoretype = 'np'

    -- Exclude previous interactions.

    left outer join tmp_previous_interactions as P
        on I.rig = P.id
    where P.rig is null
    group by C.crigid, I.rig, D.description, H.score, L.score, N.score

    -- Combine with previous interactions, but only those present in the current
    -- release.

    union all
    select distinct P.id, P.version, P.rig, P.rigid, P.name, P.description, P.hpr, P.lpr, P.np
    from tmp_previous_interactions as P
    inner join irefindex_rigids_canonical as C
        on P.rigid = C.crigid;

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

\copy tmp_previous_interactor_detection_types from '<directory>/old_irefweb_interactor_detection_type'

analyze tmp_previous_interactor_detection_types;

-- Combine previously unknown interactor detection types with the previous table.

create temporary sequence tmp_irefweb_interactor_detection_types_id minvalue 0;

select setval('tmp_irefweb_interactor_detection_types_id', coalesce(max(id), 0))
from tmp_previous_interactor_detection_types;

-- NOTE: Feature detection methods are not present here.
-- NOTE: iRefWeb 9 seems to have pipe-separated capitalised method names.

create temporary table tmp_irefweb_interactor_detection_types as
    select
        nextval('tmp_irefweb_interactor_detection_types_id') as id,
        (select max(version) + 1 from tmp_previous_interactor_detection_types) as version,
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

\copy tmp_previous_interaction_detection_types from '<directory>/old_irefweb_interaction_detection_type'

analyze tmp_previous_interaction_detection_types;

-- Combine previously unknown interaction detection types with the previous table.

create temporary sequence tmp_irefweb_interaction_detection_types_id minvalue 0;

select setval('tmp_irefweb_interaction_detection_types_id', coalesce(max(id), 0))
from tmp_previous_interaction_detection_types;

-- NOTE: Feature detection methods are not present here.

create temporary table tmp_irefweb_interaction_detection_types as
    select
        nextval('tmp_irefweb_interaction_detection_types_id') as id,
        (select max(version) + 1 from tmp_previous_interaction_detection_types) as version,
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
-- Although the PSI-MI code would be the obvious choice to distinguish between
-- interaction types, iRefWeb 9 seems to use the name and also provides
-- potentially many names per PSI-MI code.

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

update tmp_previous_interaction_types set description = null where description = 'NULL';

analyze tmp_previous_interaction_types;

-- Combine previously unknown interaction types with the previous table.

create temporary sequence tmp_irefweb_interaction_types_id minvalue 0;

select setval('tmp_irefweb_interaction_types_id', coalesce(max(id), 0))
from tmp_previous_interaction_types;

create temporary table tmp_irefweb_interaction_types as
    select
        nextval('tmp_irefweb_interaction_types_id') as id,
        (select max(version) + 1 from tmp_previous_interaction_types) as version,
        X.name, X.description, X.psi_mi_code, X.geneticInteraction
    from (
        select
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

        group by T.name, T.code, G.code

        ) as X

    -- Exclude previous interaction types.

    left outer join tmp_previous_interaction_types as P
        on X.name = P.name
    where P.id is null

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
    release_date varchar,
    release_label varchar,
    comments varchar,
    primary key(id)
);

\copy tmp_previous_source_databases from '<directory>/old_irefweb_source_db'

update tmp_previous_source_databases set release_date = null where release_date = '0000-00-00 00:00:00';
update tmp_previous_source_databases set comments = null where comments = 'NULL';

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
-- NOTE: This process needs refining because of the different forms of various
-- NOTE: names.

create temporary sequence tmp_irefweb_source_databases_id minvalue 0;

select setval('tmp_irefweb_source_databases_id', coalesce(max(id), 0))
from tmp_previous_source_databases;

create temporary table tmp_irefweb_source_databases as
    select
        nextval('tmp_irefweb_source_databases_id') as id,
        (select max(version) + 1 from tmp_previous_source_databases) as version,
        C.name,
        cast(C.release_date as varchar),
        C.release_label,
        C.comments
    from tmp_current_source_databases as C

    -- Exclude previous source databases.

    left outer join tmp_previous_source_databases as P

        -- Normalise the names in order to match more easily.

        on lower(C.name) = lower(P.name)

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
    source_db_id varchar,
    primary key(id)
);

\copy tmp_previous_name_spaces from '<directory>/old_irefweb_name_space'

update tmp_previous_name_spaces set source_db_id = null where source_db_id = 'NULL';

-- Combine previously unknown name spaces with the previous table.
-- NOTE: This process needs refining because of the different forms of various
-- NOTE: names.

create temporary sequence tmp_irefweb_name_spaces_id minvalue 0;

select setval('tmp_irefweb_name_spaces_id', coalesce(max(id), 0))
from tmp_previous_name_spaces;

create temporary table tmp_irefweb_name_spaces as
    select
        nextval('tmp_irefweb_name_spaces_id') as id,
        (select max(version) + 1 from tmp_previous_name_spaces) as version,
        S.name,
        cast(S.id as varchar) as source_db_id
    from tmp_irefweb_source_databases as S

    -- Exclude previous name spaces.

    left outer join tmp_previous_name_spaces as P

        -- Normalise the names in order to match more easily.

        on lower(S.name) = lower(P.name)

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
        substring(C.crogid for 27) as seguid,

        -- Taxonomy information.

        cast(substring(C.crogid from 28) as integer) as taxonomy_id,
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
        and V.nametype = 'preferred'

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

create index tmp_interactors_index on tmp_interactors(source, filename, entry, interactorid);
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

\copy tmp_previous_interactor_types from '<directory>/old_irefweb_interactor_type'

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
        (select max(version) + 1 from tmp_previous_interactor_types) as version,
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



-- Build an aliases register.

create temporary table tmp_display_aliases as

    -- Add UniProt identifiers.

    select interactor_id, rogid, uniprotid as alias, N.id as name_space_id
    from (
        select rog as interactor_id, I.rogid, min(uniprotid) as uniprotid
        from tmp_interactors as I
        inner join tmp_uniprot_rogids as U
            on I.rogid = U.rogid
        group by rog, I.rogid
        ) as X
    inner join tmp_irefweb_name_spaces as N
        on N.name = 'uniprotkb'
    union all

    -- Add preferred identifiers for any remaining interactors.

    select interactor_id, rogid, details[1] as alias, N.id as name_space_id
    from (
        select rog as interactor_id, I.rogid, min(array[refvalue, dblabel]) as details
        from tmp_interactors as I
        inner join irefindex_rogid_identifiers_preferred as P
            on I.rogid = P.rogid
        left outer join tmp_uniprot_rogids as U
            on I.rogid = U.rogid
        where U.rogid is null
        group by rog, I.rogid
        ) as X
    inner join tmp_irefweb_name_spaces as N
        on X.details[2] = N.name;

create temporary table tmp_aliases as
    select interactor_id, rogid, alias, name_space_id
    from (
        select rog as interactor_id, rogid, used_alias as alias, used_name_space_id as name_space_id
        from tmp_interactors
        union
        select rog as interactor_id, rogid, final_alias as alias, final_name_space_id as name_space_id
        from tmp_interactors
        union
        select rog as interactor_id, rogid, primary_alias as alias, primary_name_space_id as name_space_id
        from tmp_interactors
        union
        select rog as interactor_id, rogid, canonical_alias as alias, canonical_name_space_id as name_space_id
        from tmp_interactors
        ) as X
    union all
    select interactor_id, rogid, alias, name_space_id
    from tmp_display_aliases;

analyze tmp_aliases;



-- Aliases are an aggregation of different name information with an arbitrary
-- sequence number assigned to each one.

-- Use a sequence to number aliases.

create temporary sequence tmp_irefweb_aliases_id minvalue 0;

select setval('tmp_irefweb_aliases_id', 0);

-- NOTE: iRefWeb 9 uses version 1 for short labels, aliases and full names from
-- NOTE: the name (not xref) information for each interactor, along with xref
-- NOTE: accessions in both original and mapped forms. It uses version 2 for
-- NOTE: accessions also apparently related to the original and mapped forms.

create temporary table tmp_irefweb_aliases as
    select distinct
        nextval('tmp_irefweb_aliases_id') as id,
        1 as version,
        alias,
        name_space_id
    from tmp_aliases
    group by alias, name_space_id;

create index tmp_irefweb_aliases_index on tmp_irefweb_aliases(alias, name_space_id);

analyze tmp_irefweb_aliases;

\copy tmp_irefweb_aliases to '<directory>/irefweb_alias'



-- Interactor aliases map interactors to aliases.
-- The surrogate key needs to be obtained from the generated aliases table.

create temporary sequence tmp_irefweb_interactor_aliases_id minvalue 0;

select setval('tmp_irefweb_interactor_aliases_id', 0);

create temporary table tmp_irefweb_interactor_aliases as
    select nextval('tmp_irefweb_interactor_aliases_id') as id,
        1 as version,
        X.interactor_id,
        A.id as alias_id
    from tmp_aliases as X
    inner join tmp_irefweb_aliases as A
        on X.alias = A.alias
        and X.name_space_id = A.name_space_id
    group by X.interactor_id, A.id;

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
    select S.sequence, actualsequence, 'uniprotkb' as sourcedb
    from uniprot_sequences as S
    inner join irefindex_assignments as R
        on S.sequence = R.sequence
    union all
    select S.sequence, actualsequence, 'refseq' as sourcedb
    from refseq_sequences as S
    inner join irefindex_assignments as R
        on S.sequence = R.sequence
    union all
    select S.sequence, actualsequence, 'ipi' as sourcedb
    from ipi_sequences as S
    inner join irefindex_assignments as R
        on S.sequence = R.sequence
    union all
    select S.sequence, actualsequence, 'genpept' as sourcedb
    from genpept_sequences as S
    inner join irefindex_assignments as R
        on S.sequence = R.sequence
    union all
    select S.sequence, actualsequence, 'pdb' as sourcedb
    from pdb_sequences as S
    inner join irefindex_assignments as R
        on S.sequence = R.sequence
    union all
    select S.sequence, actualsequence, source as sourcedb
    from xml_sequences_original as S
    inner join irefindex_assignments as R
        on S.sequence = R.sequence;

analyze tmp_current_sequences;

-- Use a sequence to number previously unknown sequences.

create temporary sequence tmp_irefweb_sequences_id minvalue 0;

select setval('tmp_irefweb_sequences_id', coalesce(max(id), 0))
from tmp_previous_sequences;

create temporary table tmp_irefweb_sequences as
    select nextval('tmp_irefweb_sequences_id') as id,
        (select max(version) + 1 from tmp_previous_sequences) as version,
        S.sequence as seguid,
        actualsequence as "sequence"
    from tmp_current_sequences as S

    -- Exclude previous sequences.

    left outer join tmp_previous_sequences as P
        on S.sequence = P.seguid
    where P.seguid is null
    group by S.sequence, actualsequence

    -- Combine with previous sequences.

    union all
    select id, version, seguid, "sequence"
    from tmp_previous_sequences;

\copy tmp_irefweb_sequences to '<directory>/irefweb_sequence'



-- Sequence source databases.

create temporary table tmp_previous_sequence_databases (
    id integer not null,
    version integer not null,
    source_db_sqnc_id integer not null,
    sequence_id integer not null,
    source_db_id integer not null,
    primary key(id)
);

\copy tmp_previous_sequence_databases from '<directory>/old_irefweb_sequence_source_db'

analyze tmp_previous_sequence_databases;

-- Combine previously unknown sequence databases with the previous table.

create temporary sequence tmp_irefweb_sequence_databases_id minvalue 0;

select setval('tmp_irefweb_sequence_databases_id', coalesce(max(id), 0))
from tmp_previous_sequence_databases;

-- NOTE: source_db_sqnc_id and sequence_id are always identical in iRefWeb 9.
-- NOTE: A preferred database identifier seems to be chosen in iRefWeb 9 so that
-- NOTE: only one record exists per sequence.

create temporary table tmp_current_sequence_databases as
    select
        S.id as source_db_sqnc_id,
        S.id as sequence_id,
        min(D.id) as source_db_id
    from tmp_current_sequences as C
    inner join tmp_irefweb_sequences as S
        on C.actualsequence = S.sequence
    inner join tmp_irefweb_source_databases as D
        on lower(sourcedb) = lower(D.name)
    group by S.id;

analyze tmp_current_sequence_databases;

create temporary table tmp_irefweb_sequence_databases as
    select
        nextval('tmp_irefweb_sequence_databases_id') as id,
        (select max(version) + 1 from tmp_previous_sequence_databases) as version,
        C.source_db_sqnc_id, C.sequence_id, C.source_db_id
    from tmp_current_sequence_databases as C

    -- Exclude previous sequence databases.

    left outer join tmp_previous_sequence_databases as P
        on C.sequence_id = P.sequence_id
    where P.sequence_id is null

    -- Combine with previous sequence databases, but only those present in the
    -- current release.

    union all
    select P.id, P.version, P.source_db_sqnc_id, P.sequence_id, P.source_db_id
    from tmp_previous_sequence_databases as P
    inner join tmp_current_sequence_databases as C
        on P.sequence_id = C.sequence_id;

\copy tmp_irefweb_sequence_databases to '<directory>/irefweb_sequence_source_db'



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

\copy tmp_previous_interactors from '<directory>/old_irefweb_interactor'

analyze tmp_previous_interactors;

-- Combine previously unknown interactors with the previous table.
-- NOTE: iRefWeb 9 just chooses "protein" as the interactor type regardless of
-- NOTE: what the source records say.

create temporary table tmp_irefweb_interactors as
    select distinct
        I.rog,
        I.rogid,
        I.seguid,
        I.taxonomy_id,
        (select id from tmp_irefweb_interactor_types where name = 'protein') as interactor_type_id,
        IA.id as display_interactor_alias_id,
        S.id as sequence_id,
        I.rog as id,
        (select max(version) + 1 from tmp_previous_interactors) as version
    from tmp_interactors as I

    -- Need to choose only one alias, preferably a UniProt identifier.

    inner join tmp_display_aliases as D
        on I.rog = D.interactor_id
    inner join tmp_irefweb_interactor_aliases as IA
        on D.interactor_id = IA.interactor_id
    inner join tmp_irefweb_aliases as A
        on IA.alias_id = A.id
        and D.alias = A.alias
        and D.name_space_id = A.name_space_id
    inner join tmp_irefweb_sequences as S
        on I.seguid = S.seguid

    -- Exclude previous interactors.

    left outer join tmp_previous_interactors as P
        on I.rog = P.id
    where P.id is null

    -- Combine with previous interactors, but only those present in the current
    -- release.

    union all
    select distinct P.rog, P.rogid, P.seguid, P.taxonomy_id, P.interactor_type_id, P.display_interactor_alias_id, P.sequence_id, P.id, P.version
    from tmp_previous_interactors as P
    inner join tmp_interactors as I
        on P.id = I.rog;

analyze tmp_irefweb_interactors;

\copy tmp_irefweb_interactors to '<directory>/irefweb_interactor'



-- Create a mapping from canonical interactions to canonical interactors.

-- Get old mappings.

create temporary table tmp_previous_interaction_interactors (
    id integer not null,
    version integer not null,
    interaction_id integer not null,
    interactor_id integer not null,
    cardinality integer not null,
    primary key(id)
);

\copy tmp_previous_interaction_interactors from '<directory>/old_irefweb_interaction_interactor'

-- Combine previously unknown mappings with the previous table.

create temporary sequence tmp_irefweb_interaction_interactors_id minvalue 0;

select setval('tmp_irefweb_interaction_interactors_id', coalesce(max(id), 0))
from tmp_previous_interaction_interactors;

create temporary table tmp_irefweb_interaction_interactors as
    select
        nextval('tmp_irefweb_interaction_interactors_id') as id,
        (select max(version) + 1 from tmp_previous_interaction_interactors) as version,
        II.rig as interaction_id,
        IO.rog as interactor_id,
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
        on II.rig = P.interaction_id
        and IO.rog = P.interactor_id
    where P.interaction_id is null
    group by II.rig, IO.rog

    -- Combine with previous mappings, retaining only those that are still
    -- present.

    union all
    select distinct id, version, interaction_id, interactor_id, cardinality
    from tmp_previous_interaction_interactors as P
    inner join irefindex_rig2rigid as II
        on P.interaction_id = II.rig
    inner join irefindex_rog2rogid as IO
        on P.interactor_id = IO.rog
    inner join irefindex_rigids_canonical as CI
        on II.rigid = CI.crigid
    inner join irefindex_rogids_canonical as CO
        on IO.rogid = CO.crogid;

\copy tmp_irefweb_interaction_interactors as '<directory>/irefweb_interaction_interactor'

create index tmp_irefweb_interaction_interactors_index on tmp_irefweb_interaction_interactors(interaction_id, interactor_id);
analyze tmp_irefweb_interaction_interactors;



-- Map source interactions to general interactions.
-- NOTE: Since interaction type codes can produce multiple type records, the
-- NOTE: lowest identifier is chosen.
-- NOTE: iRefWeb 9 seems to take arbitrary identifiers for the interaction
-- NOTE: identifier where no explicit identifier has been provided.

create temporary table tmp_interaction_sources as
    select
        CI.rig as interaction_id,
        N.refvalue as source_db_intrctn_id,
        D.id as source_db_id,
        min(IT.id) as interaction_type_id,

        -- Maintain the reference to the interaction record for later use.

        N.source, N.filename, N.entry, N.interactionid

    from irefindex_rigids as R
    inner join irefindex_rigids_canonical as C
        on R.rigid = C.rigid
    inner join irefindex_rig2rigid as CI
        on C.crigid = CI.rigid
    left outer join xml_xref_interactions as N
        on (R.source, R.filename, R.entry, R.interactionid)
         = (N.source, N.filename, N.entry, N.interactionid)
    left outer join tmp_irefweb_source_databases as D
        on lower(R.source) = lower(D.name)
    left outer join xml_xref_interaction_types as T
        on (R.source, R.filename, R.entry, R.interactionid)
         = (T.source, T.filename, T.entry, T.interactionid)
    left outer join tmp_irefweb_interaction_types as IT
        on T.refvalue = IT.psi_mi_code

    group by CI.rig, N.refvalue, D.id, N.source, N.filename, N.entry, N.interactionid;

create index tmp_interaction_sources_index on tmp_interaction_sources(source, filename, entry, interactionid);
analyze tmp_interaction_sources;



-- Create a record of specific interactions (interactions with source
-- information).

-- Get old source interactions.

create temporary table tmp_previous_interaction_sources (
    id integer not null,
    version integer not null,
    interaction_id integer not null,
    source_db_intrctn_id varchar,
    source_db_id integer,
    interaction_type_id integer not null,
    primary key(id)
);

\copy tmp_previous_interaction_sources from '<directory>/old_irefweb_interaction_source_db'

-- Combine previously unknown source interactions with the previous table.

create temporary sequence tmp_irefweb_interaction_sources_id minvalue 0;

select setval('tmp_irefweb_interaction_sources_id', coalesce(max(id), 0))
from tmp_previous_interaction_sources;

create temporary table tmp_irefweb_interaction_sources as
    select 
        nextval('tmp_irefweb_interaction_sources_id') as id,
        (select max(version) + 1 from tmp_previous_interaction_sources) as version,
        X.interaction_id, X.source_db_intrctn_id, X.source_db_id, X.interaction_type_id
    from (
        select distinct interaction_id, source_db_intrctn_id, source_db_id, interaction_type_id
        from tmp_interaction_sources
        ) as X

    -- Exclude previous source interactions.

    left outer join tmp_previous_interaction_sources as P
        on X.source_db_intrctn_id = P.source_db_intrctn_id
        and X.source_db_id = P.source_db_id
        and X.interaction_id = P.interaction_id

    where P.source_db_intrctn_id is null

    -- Combine with previous source interactions.

    union all
    select id, version, interaction_id, source_db_intrctn_id, source_db_id, interaction_type_id
    from tmp_previous_interaction_sources;

\copy tmp_irefweb_interaction_sources to '<directory>/irefweb_interaction_source_db'

create index tmp_irefweb_interaction_sources_index on tmp_irefweb_interaction_sources(interaction_id, source_db_intrctn_id, source_db_id, interaction_type_id);
analyze tmp_irefweb_interaction_sources;



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

create temporary sequence tmp_irefweb_scores_id minvalue 0;

select setval('tmp_irefweb_scores_id', coalesce(max(id), 0))
from tmp_previous_scores;

create temporary table tmp_irefweb_scores as
    select distinct
        nextval('tmp_irefweb_scores_id') as id,
        (select max(version) + 1 from tmp_previous_scores) as version,
        score as code,
        cast('' as varchar) as description
    from (
        select distinct
            case when score like '%+%' then substring(score for position('+' in score) - 1) || substring(score from position('+' in score) + 1) || '+'
                 else score
            end as score
        from irefindex_assignment_scores
        ) as S

    -- Exclude previous scores.

    left outer join tmp_previous_scores as P
        on S.score = P.code
    where P.code is null

    -- Combine with previous scores.

    union all
    select id, version, code, description
    from tmp_previous_scores;

\copy tmp_irefweb_scores to '<directory>/irefweb_score'



-- Collect scores for canonical interactors. Since scoring is related to
-- specific interactors and not general interactors, the "best" score is chosen
-- for each canonical interactor.

create temporary table tmp_score_values as
    select code,
        case when code like '%P%' then 1 else 0 end +
        case when code like '%S%' then 2 else 0 end +
        case when code like '%U%' then 4 else 0 end +
        case when code like '%V%' then 8 else 0 end +
        case when code like '%T%' then 16 else 0 end +
        case when code like '%G%' then 32 else 0 end +
        case when code like '%D%' then 64 else 0 end +
        case when code like '%M%' then 128 else 0 end +
        case when code like '%+%' then 256 else 0 end +
        case when code like '%O%' then 512 else 0 end +
        case when code like '%X%' then 1024 else 0 end +
        case when code like '%L%' then 4096 else 0 end +
        case when code like '%I%' then 8192 else 0 end +
        case when code like '%E%' then 16384 else 0 end +
        case when code like '%Y%' then 32768 else 0 end +
        case when code like '%N%' then 65536 else 0 end +
        case when code like '%Q%' then 131072 else 0 end as value
    from tmp_irefweb_scores;

analyze tmp_score_values;

create temporary table tmp_canonical_scores as
    select rogid, code
    from (
        select C.crogid as rogid, min(value) as value
        from irefindex_rogids_canonical as C
        inner join irefindex_rogids as R
            on C.crogid = R.rogid
        inner join irefindex_assignment_scores as A
            on (R.source, R.filename, R.entry, R.interactorid)
             = (A.source, A.filename, A.entry, A.interactorid)
        inner join tmp_score_values as S
            on A.score = S.code
        group by C.crogid
        ) as X
    inner join tmp_score_values as S
        on X.value = S.value;

analyze tmp_canonical_scores;



-- Map experiments to PubMed identifiers and methods.
-- NOTE: Since interaction detection type codes can produce multiple type
-- NOTE: records, the lowest identifier is chosen.

create temporary table tmp_experiments as
    select EP.refvalue as pubmed_id, min(IDT.id) as interaction_detection_type_id,
        case when EP.reftype = 'secondaryRef' then 1 else 0 end as isSecondary,
        EP.source, EP.filename, EP.entry, EP.experimentid
    from xml_xref_experiment_pubmed as EP
    left outer join xml_xref_experiment_methods as EM
        on (EP.source, EP.filename, EP.entry, EP.experimentid)
         = (EM.source, EM.filename, EM.entry, EM.experimentid)
    left outer join tmp_irefweb_interaction_detection_types as IDT
        on EM.refvalue = IDT.psi_mi_code
        and EM.property = 'interactionDetectionMethod'
    group by EP.refvalue, EP.reftype, EP.source, EP.filename, EP.entry, EP.experimentid;

analyze tmp_experiments;

-- Map experiments to specific/source interactions.

create temporary table tmp_interaction_experiments as
    select S2.id as interaction_source_db_id, S.interaction_id,
        E.source, E.filename, E.entry, E.experimentid, E.interactionid
    from xml_experiments as E
    inner join tmp_interaction_sources as S
        on (E.source, E.filename, E.entry, E.interactionid)
         = (S.source, S.filename, S.entry, S.interactionid)
    inner join tmp_irefweb_interaction_sources as S2
        on (S.interaction_id, S.source_db_intrctn_id, S.source_db_id)
         = (S2.interaction_id, S2.source_db_intrctn_id, S2.source_db_id);

analyze tmp_interaction_experiments;



-- Experiment details indicating the bait of a specific interaction along with
-- the interaction detection type and PubMed reference.

create temporary table tmp_previous_interaction_experiments (
    id integer not null,
    version integer not null,
    interaction_source_db_id integer not null,
    bait_interaction_interactor_id varchar,
    pubmed_id varchar not null,
    interaction_detection_type_id varchar,
    isSecondary integer,
    primary key(id)
);

\copy tmp_previous_interaction_experiments from '<directory>/old_irefweb_interaction_source_db_experiment'

update tmp_previous_interaction_experiments set bait_interaction_interactor_id = null where bait_interaction_interactor_id = 'NULL';
update tmp_previous_interaction_experiments set interaction_detection_type_id = null where interaction_detection_type_id = 'NULL';

alter table tmp_previous_interaction_experiments alter column bait_interaction_interactor_id type integer using cast(bait_interaction_interactor_id as integer);
alter table tmp_previous_interaction_experiments alter column interaction_detection_type_id type integer using cast(interaction_detection_type_id as integer);

-- Combine previously unknown interaction experiments with the previous table.

create temporary sequence tmp_irefweb_interaction_experiments_id minvalue 0;

select setval('tmp_irefweb_interaction_experiments_id', coalesce(max(id), 0))
from tmp_previous_interaction_experiments;

create temporary table tmp_irefweb_interaction_experiments as
    select
        nextval('tmp_irefweb_interaction_experiments_id') as id,
        (select max(version) + 1 from tmp_previous_interaction_experiments) as version,
        E.interaction_source_db_id,
        II.id as bait_interaction_interactor_id,
        EP.pubmed_id,
        EP.interaction_detection_type_id,
        EP.isSecondary
    from tmp_experiments as EP

    -- Interaction source details.

    inner join tmp_interaction_experiments as E
        on (EP.source, EP.filename, EP.entry, EP.experimentid)
         = (E.source, E.filename, E.entry, E.experimentid)

    -- Bait information.

    left outer join tmp_bait_interactors as B
        on (E.source, E.filename, E.entry, E.interactionid)
         = (B.source, B.filename, B.entry, B.interactionid)
    left outer join tmp_irefweb_interaction_interactors as II
        on B.interactor_id = II.interactor_id
        and E.interaction_id = II.interaction_id

    -- Exclude previous details.

    left outer join tmp_previous_interaction_experiments as P
        on E.interaction_source_db_id = P.interaction_source_db_id

    where P.interaction_source_db_id is null

    -- Combine with previous details.

    union all
    select P.id, P.version, P.interaction_source_db_id, P.bait_interaction_interactor_id, P.pubmed_id, P.interaction_detection_type_id, P.isSecondary
    from tmp_previous_interaction_experiments as P
    inner join tmp_interaction_experiments as E
        on E.interaction_source_db_id = P.interaction_source_db_id;

\copy tmp_irefweb_interaction_experiments to '<directory>/irefweb_interaction_source_db_experiment'



-- Map participants to methods.
-- NOTE: Since interactor detection type codes can produce multiple type
-- NOTE: records, the lowest identifier is chosen.

create temporary table tmp_interaction_participants as
    select min(IDT.id) as interactor_detection_type_id,
        I.source, I.filename, I.entry, I.interactionid, I.interactorid, I.participantid
    from xml_interactors as I
    left outer join xml_xref_participants as P
        on (I.source, I.filename, I.entry, I.participantid)
         = (P.source, P.filename, P.entry, P.participantid)
        and P.property = 'participantIdentificationMethod'
    left outer join tmp_irefweb_interactor_detection_types as IDT
        on P.refvalue = IDT.psi_mi_code
    group by I.source, I.filename, I.entry, I.interactionid, I.interactorid, I.participantid;

analyze tmp_interaction_participants;

-- Map participants to identifiers.

create temporary table tmp_participant_assignments as
    select
        II.id as interaction_interactor_id,
        E.interaction_source_db_id,
        IP.interactor_detection_type_id,
        IP.source, IP.filename, IP.entry, IP.interactionid, IP.interactorid, IP.participantid

    from tmp_irefweb_interaction_interactors as II

    -- Experimental details.

    inner join tmp_interaction_experiments as E
        on II.interaction_id = E.interaction_id

    -- Interactor and assignment details.

    inner join tmp_interaction_participants as IP
        on (E.source, E.filename, E.entry, E.interactionid)
         = (IP.source, IP.filename, IP.entry, IP.interactionid)

    inner join tmp_interactors as I
        on (IP.source, IP.filename, IP.entry, IP.interactorid)
         = (I.source, I.filename, I.entry, I.interactorid)
        and II.interactor_id = I.rog;

analyze tmp_participant_assignments;

-- Map interactors to alias identifiers.

create temporary table tmp_interactor_aliases as
    select
        primaryA.id as primary_alias_id,
        usedA.id as used_alias_id,
        finalA.id as final_alias_id,
        canonicalA.id as canonical_alias_id,
        scores.id as score_id,
        scoresC.id as canonical_score_id,
        primary_taxonomy_id,
        used_taxonomy_id,
        used_taxonomy_id as final_taxonomy_id,
        I.source, I.filename, I.entry, I.interactorid

    from tmp_interactors as I
    inner join tmp_irefweb_aliases as usedA
        on I.used_alias = usedA.alias
        and I.used_name_space_id = usedA.name_space_id
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

    left outer join tmp_irefweb_scores as scores
        on I.score = scores.code

    -- Canonical score details.

    left outer join tmp_canonical_scores as CS
        on I.rogid = CS.rogid
    left outer join tmp_irefweb_scores as scoresC
        on CS.code = scoresC.code;

analyze tmp_interactor_aliases;



-- Assignments map canonical interactors to name and method information.

create temporary table tmp_previous_assignments (
    id integer not null,
    version integer not null,
    interaction_interactor_id integer not null,
    interaction_source_db_id integer not null,
    interactor_detection_type_id varchar,
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

\copy tmp_previous_assignments from '<directory>/old_irefweb_interaction_interactor_assignment'

update tmp_previous_assignments set interactor_detection_type_id = null where interactor_detection_type_id = 'NULL';
alter table tmp_previous_assignments alter column interactor_detection_type_id type integer using cast(interactor_detection_type_id as integer);

create index tmp_previous_assignments_index on tmp_previous_assignments(interaction_interactor_id, interaction_source_db_id, position_as_found_in_source_db);
analyze tmp_previous_assignments;

-- Create a record of assignments.

create temporary sequence tmp_irefweb_assignments_id minvalue 0;

select setval('tmp_irefweb_assignments_id', coalesce(max(id), 0))
from tmp_previous_assignments;

-- NOTE: The distinction needs to be made between used and final taxonomy identifiers.

create temporary table tmp_irefweb_assignments as
    select
        nextval('tmp_irefweb_assignments_id') as id,
        (select max(version) + 1 from tmp_previous_assignments) as version,
        PA.interaction_interactor_id,
        PA.interaction_source_db_id,
        PA.interactor_detection_type_id,
        IA.primary_alias_id,
        IA.used_alias_id,
        IA.final_alias_id,
        IA.canonical_alias_id,
        IA.primary_taxonomy_id,
        IA.used_taxonomy_id,
        IA.final_taxonomy_id,
        positions.index as position_as_found_in_source_db,
        IA.score_id,
        IA.canonical_score_id

    from tmp_participant_assignments as PA
    inner join tmp_interactor_aliases as IA
        on (PA.source, PA.filename, PA.entry, PA.interactorid)
         = (IA.source, IA.filename, IA.entry, IA.interactorid)

    -- Participant details.

    inner join tmp_participant_positions as positions
        on (PA.source, PA.filename, PA.entry, PA.interactionid, PA.interactorid, PA.participantid)
         = (positions.source, positions.filename, positions.entry, positions.interactionid, positions.interactorid, positions.participantid)

    -- Exclude previous assignments.

    left outer join tmp_previous_assignments as P
        on PA.interaction_interactor_id = P.interaction_interactor_id
        and PA.interaction_source_db_id = P.interaction_source_db_id
        and positions.index = P.position_as_found_in_source_db

    where P.interaction_interactor_id is null

    -- Combine with previous assignments.

    union all
    select distinct P.id, P.version, P.interaction_interactor_id, P.interaction_source_db_id, P.interactor_detection_type_id,
        P.primary_alias_id, P.used_alias_id, P.final_alias_id, P.canonical_alias_id,
        P.primary_taxonomy_id, P.used_taxonomy_id, P.final_taxonomy_id,
        P.position_as_found_in_source_db,
        P.score_id, P.canonical_score_id
    from tmp_previous_assignments as P
    inner join tmp_participant_assignments as PA
        on (P.interaction_interactor_id, P.interaction_source_db_id)
         = (PA.interaction_interactor_id, PA.interaction_source_db_id)
    inner join tmp_participant_positions as positions
        on (PA.source, PA.filename, PA.entry, PA.interactionid, PA.interactorid, PA.participantid, P.position_as_found_in_source_db)
         = (positions.source, positions.filename, positions.entry, positions.interactionid, positions.interactorid, positions.participantid, positions.index);

\copy tmp_irefweb_assignments to '<directory>/irefweb_interaction_interactor_assignment'



-- A mapping from gene identifiers to ROG identifiers.
-- NOTE: The interactor identifier is the same as the integer ROG identifier.

create temporary table tmp_irefweb_gene2rog as
    select R.rggid as rgg, geneid, CI.rog, R.rogid, CI.rog as interactor_id
    from irefindex_rgg_rogids_canonical as R
    inner join irefindex_rgg_genes as G
        on R.rggid = G.rggid
    inner join irefindex_rog2rogid as CI
        on R.rogid = CI.rogid
    inner join tmp_irefweb_interactors as I
        on CI.rog = I.id;

\copy tmp_irefweb_gene2rog to '<directory>/irefweb_geneid2rog'



-- NOTE: Statistics are similar to those in reports/interactions_by_source.sql.

create temporary table tmp_interactions_available_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactionid]) as total
    from xml_interactors
    group by source;

analyze tmp_interactions_available_by_source;

create temporary table tmp_interactions_having_assignments as
    select I.source, count(distinct array[I.source, I.filename, cast(I.entry as varchar), interactionid]) as total
    from (

        -- Group interactors by interaction and make sure that only interactions
        -- where all interactors provide sequences are considered.

        select I.source, I.filename, I.entry, I.interactionid
        from xml_interactors as I
        left outer join xml_xref_interactor_types as S
            on (I.source, I.filename, I.entry, I.interactorid) =
               (S.source, S.filename, S.entry, S.interactorid)
        group by I.source, I.filename, I.entry, I.interactionid
        having count(I.interactorid) = count(S.interactorid)
            and count(distinct refvalue) = 1
            and min(refvalue) = 'MI:0326'
            or count(S.interactorid) = 0
        ) as I
    group by I.source;

analyze tmp_interactions_having_assignments;

create temporary table tmp_interaction_completeness_by_source as
    select source, complete, count(distinct array[filename, cast(entry as varchar), interactionid]) as total
    from irefindex_interactions_complete
    group by source, complete
    order by source, complete;

analyze tmp_interaction_completeness_by_source;

create temporary table tmp_rigids_unique_by_source as
    select source, count(distinct rigid) as total
    from irefindex_rigids
    group by source;

analyze tmp_rigids_unique_by_source;

create temporary table tmp_rigids_canonical_unique_by_source as
    select source, count(distinct crigid) as total
    from irefindex_rigids_canonical as C
    inner join irefindex_rigids as R
        on C.rigid = R.rigid
    group by source;

analyze tmp_rigids_canonical_unique_by_source;

create temporary table tmp_interaction_coverage as
    select available.source,

        -- Available interactions.

        available.total as available_total,

        -- Suitable interactions.

        coalesce(suitable.total, 0) as suitable_total,

        -- Assigned/used RIGIDs for interactions.

        coalesce(used.total, 0) as assigned_total,

        -- Assigned/used RIGIDs as a percentage of suitable interactions.

        case when suitable.total <> 0 then
            round(
                cast(
                    cast(coalesce(used.total, 0) as real) / suitable.total * 100
                    as numeric
                    ), 2
                )
            else null
        end as assigned_coverage,

        -- Unique RIGIDs.

        coalesce(unique_rigids.total, 0) as unique_total,

        -- Unique coverage as a percentage of the number of assigned/used RIGIDs.

        case when used.total <> 0 then
            round(
                cast(
                    cast(coalesce(unique_rigids.total, 0) as real) / used.total * 100
                    as numeric
                    ), 2
                )
            else null
        end as unique_coverage,

        -- Unique canonical RIGIDs.

        coalesce(unique_rigids_canonical.total, 0) as unique_total_canonical,

        -- Unique coverage as a percentage of the number of assigned/used RIGIDs.

        case when used.total <> 0 then
            round(
                cast(
                    cast(coalesce(unique_rigids_canonical.total, 0) as real) / used.total * 100
                    as numeric
                    ), 2
                )
            else null
        end as unique_coverage_canonical

    from tmp_interactions_available_by_source as available
    left outer join tmp_interactions_having_assignments as suitable
        on available.source = suitable.source
    left outer join tmp_interaction_completeness_by_source as used
        on available.source = used.source
        and used.complete
    left outer join tmp_rigids_unique_by_source as unique_rigids
        on available.source = unique_rigids.source
    left outer join tmp_rigids_canonical_unique_by_source as unique_rigids_canonical
        on available.source = unique_rigids_canonical.source
    group by available.source, available.total, used.total, suitable.total, unique_rigids.total, unique_rigids_canonical.total
    order by available.source;



-- NOTE: Column names are taken from iRefWeb 9.
-- NOTE: Unlike the other tables, actual source names are used and not arbitrary
-- NOTE: identifiers.

create temporary table tmp_irefweb_statistics as
    select
        source                           as sourcedb,
        available_total                  as total,
        suitable_total                   as PPI,
        available_total - suitable_total as none_PPI,           -- total - PPI
        assigned_total                   as with_RIGID,
        available_total - assigned_total as no_RIGID,           -- total - with_RIGID
        suitable_total - assigned_total  as PPI_without_RIGID,  -- PPI - with_RIGID
        assigned_coverage                as percent_asign,
        unique_total                     as uniq_RIGID,
        unique_coverage                  as uniq_RIGID_perc,
        unique_total_canonical           as uniq_canonical_RIGID,
        unique_coverage_canonical        as uniq_canonical_RIGID_perc
    from tmp_interaction_coverage
    union all
    select
        'ALL'                                                                                            as sourcedb,
        sum(available_total)                                                                             as total,
        sum(suitable_total)                                                                              as PPI,
        sum(available_total) - sum(suitable_total)                                                       as none_PPI,
        sum(assigned_total)                                                                              as with_RIGID,
        sum(available_total) - sum(assigned_total)                                                       as no_RIGID,
        sum(suitable_total) - sum(assigned_total)                                                        as PPI_without_RIGID,
        round(cast(cast(sum(assigned_total) as real) / sum(suitable_total) * 100 as numeric), 2)         as percent_asign,
        sum(unique_total)                                                                                as uniq_RIGID,
        round(cast(cast(sum(unique_total) as real) / sum(assigned_total) * 100 as numeric), 2)           as uniq_RIGID_perc,
        sum(unique_total_canonical)                                                                      as uniq_canonical_RIGID,
        round(cast(cast(sum(unique_total_canonical) as real) / sum(assigned_total) * 100 as numeric), 2) as uniq_canonical_RIGID_perc
    from tmp_interaction_coverage;

\copy tmp_irefweb_statistics to '<directory>/statistics'



rollback;
