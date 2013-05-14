-- Export iRefWeb tables to files in the data directory.

-- Copyright (C) 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
-- Copyright (C) 2013 Paul Boddie <paul@boddie.org.uk>
-- Original author: Paul Boddie <paul.boddie@biotek.uio.no>
--
-- This program is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.

begin;

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
-- statistics


-- -----------------------------------------------------------------------------
-- Work tables.

-- Interactors belonging to active interactions.

create temporary table tmp_active_interactors as
    select distinct rogid
    from irefindex_distinct_interactions_canonical;

analyze tmp_active_interactors;

-- Interactor names are defined here.

create temporary table tmp_uniprot_rogids as
    select rogid, uniprotid, source
    from uniprot_proteins as P
    inner join tmp_active_interactors as I
        on P.sequence || P.taxid = I.rogid
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

-- Map specific interactors with general canonical interactors and interactions.

create temporary table tmp_bait_interactors as
    select X.source, X.filename, X.entry, X.interactionid, X.interactorid, rog, rig
    from tmp_baits as X
    inner join irefindex_rogids as R
        on (X.source, X.filename, X.entry, X.interactorid)
         = (R.source, R.filename, R.entry, R.interactorid)
    inner join irefindex_rogids_canonical as C
        on R.rogid = C.rogid
    inner join irefindex_rog2rogid as CI
        on C.crogid = CI.rogid
    inner join irefindex_rigids as R2
        on (X.source, X.filename, X.entry, X.interactionid)
         = (R2.source, R2.filename, R2.entry, R2.interactionid)
    inner join irefindex_rigids_canonical as C2
        on R2.rigid = C2.rigid
    inner join irefindex_rig2rigid as CI2
        on C2.crigid = CI2.rigid;

create index tmp_bait_interactors_index on tmp_bait_interactors(source, filename, entry, interactionid, interactorid);

analyze tmp_bait_interactors;



-- Source interactors are the basis for the interaction_interactor_assignment
-- table.

create temporary table tmp_source_interactors as
    select
        -- Specific interactor.

        R.source, R.filename, R.entry, R.interactorid,

        -- General interactor information.

        CI.rog as rog,
        C.crogid as rogid,
        substring(C.crogid for 27) as seguid,

        -- Taxonomy information.

        cast(substring(C.crogid from 28) as integer) as taxid,
        X.originaltaxid,
        O.taxid as primarytaxid,

        -- Interactor type information.

        V.name as interactortype,

        -- Alias information.

        lower(X.originaldblabel) as originaldblabel,
        X.originalrefvalue,
        lower(X.finaldblabel) as finaldblabel,
        X.finalrefvalue,
        lower(PA.dblabel) as primarydblabel,
        PA.refvalue as primaryrefvalue,
        lower(CA.dblabel) as canonicaldblabel,
        CA.refvalue as canonicalrefvalue,

        -- Assignment score information.

        case when XS.score like '%+%' then
                 substring(XS.score for position('+' in XS.score) - 1) ||
                 substring(XS.score from position('+' in XS.score) + 1) || '+'
             else XS.score
        end as code

    from irefindex_rogids as R
    inner join irefindex_rogids_canonical as C
        on R.rogid = C.rogid
    inner join irefindex_rog2rogid as CI
        on C.crogid = CI.rogid

    -- Restrict to active interactors.

    inner join tmp_active_interactors as I
        on C.crogid = I.rogid

    -- Interactor type information.

    left outer join xml_xref_interactor_types as T
        on (R.source, R.filename, R.entry, R.interactorid)
         = (T.source, T.filename, T.entry, T.interactorid)
    left outer join psicv_terms as V
        on T.refvalue = V.code
        and V.nametype = 'preferred'

    -- Alias information.

    inner join irefindex_assignments as X
        on (R.source, R.filename, R.entry, R.interactorid)
         = (X.source, X.filename, X.entry, X.interactorid)

    -- Assignment score information.

    inner join irefindex_assignment_scores as XS
        on (R.source, R.filename, R.entry, R.interactorid)
         = (XS.source, XS.filename, XS.entry, XS.interactorid)

    -- Primary alias information.

    left outer join xml_xref_all_interactors as PA
        on (R.source, R.filename, R.entry, R.interactorid)
         = (PA.source, PA.filename, PA.entry, PA.interactorid)
        and PA.reftype = 'primaryRef'

    -- Primary taxonomy information.

    left outer join xml_organisms as O
        on (X.source, X.filename, X.entry, X.interactorid)
         = (O.source, O.filename, O.entry, O.parentid)
        and O.scope = 'interactor'

    -- Canonical alias information.

    inner join irefindex_rogid_identifiers_preferred as CA
        on C.crogid = CA.rogid;

analyze tmp_source_interactors;

-- Source interaction participants.
-- NOTE: Since interactor detection type codes can produce multiple type
-- NOTE: records, the lowest identifier is chosen.

create temporary table tmp_source_participants as
    select
        -- Specific interaction.

        source, filename, entry, interactionid,

        -- Position of the participant in the interaction.

        "index",

        -- Specific interactor and participant details.

        interactors["index"][1] as interactorid,
        interactors["index"][2] as participantid,
        interactors["index"][3] as interactordetectiontype

    from (

        -- Enumerate the participants.

        select
            source, filename, entry, interactionid,
            generate_subscripts(interactors, 1) as "index", interactors

        from (

            -- Collect the participants for enumeration.

            select
                source, filename, entry, interactionid,
                array_array_accum(array[[interactorid, participantid, refvalue]]) as interactors

            from (

                select
                    -- Source participant with interaction and interactor details.

                    I.source, I.filename, I.entry, I.interactionid, I.interactorid, I.participantid,

                    -- Interactor detection type.

                    min(refvalue) as refvalue

                    from xml_interactors as I
                    left outer join xml_xref_participants as P
                        on (I.source, I.filename, I.entry, I.participantid)
                         = (P.source, P.filename, P.entry, P.participantid)
                        and P.property = 'participantIdentificationMethod'
                    group by I.source, I.filename, I.entry, I.interactionid, I.interactorid, I.participantid
                    order by I.source, I.filename, I.entry, I.interactionid, I.participantid
                ) as X

            group by source, filename, entry, interactionid

            ) as X

        ) as X;

analyze tmp_source_participants;

-- Source interactions are the basis for the interaction_source_db table.
-- NOTE: There appear to be some interactions providing multiple interaction
-- NOTE: types in MPIDB, so this has to discard such redundant types (MI:0407
-- NOTE: is a form of MI:0915 and thus the latter is redundant).

create temporary table tmp_source_interactions as
    select
        -- Specific interaction.

        R.source, R.filename, R.entry, R.interactionid,

        -- General interaction.

        C.crigid as rigid, CI.rig,

        -- Interaction identifier.

        lower(N.dblabel) as dblabel, N.refvalue,

        -- Interaction type.
        -- NOTE: min just happens to select the appropriate values but is not
        -- NOTE: appropriate in general.

        min(T.refvalue) as interactiontype

    from irefindex_rigids as R
    inner join irefindex_rigids_canonical as C
        on R.rigid = C.rigid
    inner join irefindex_rig2rigid as CI
        on C.crigid = CI.rigid
    left outer join xml_xref_interactions as N
        on (R.source, R.filename, R.entry, R.interactionid)
         = (N.source, N.filename, N.entry, N.interactionid)
    left outer join xml_xref_interaction_types as T
        on (R.source, R.filename, R.entry, R.interactionid)
         = (T.source, T.filename, T.entry, T.interactionid)

    -- Grouping to eliminate redundant interaction types.

    group by R.source, R.filename, R.entry, R.interactionid,
        C.crigid, CI.rig, lower(N.dblabel), N.refvalue;

create index tmp_source_interactions_index on tmp_source_interactions(source, filename, entry, interactionid);

analyze tmp_source_interactions;

-- Source experiments are the basis for the interaction_source_db_experiment
-- table when combined with the source interactions.

create temporary table tmp_source_experiments as
    select
        -- Specific experiment.
 
        EP.source, EP.filename, EP.entry, EP.experimentid,

        -- PubMed identifier.

        EP.refvalue as pmid,
        EP.reftype,

        -- Interaction detection type.

        EM.refvalue as interactiondetectiontype

    from xml_xref_experiment_pubmed as EP
    left outer join xml_xref_experiment_methods as EM
        on (EP.source, EP.filename, EP.entry, EP.experimentid)
         = (EM.source, EM.filename, EM.entry, EM.experimentid);

create index tmp_source_experiments_index on tmp_source_experiments(source, filename, entry, experimentid);

analyze tmp_source_experiments;

create temporary table tmp_source_interaction_experiments as
    select
        -- Specific interaction (providing the source interaction reference).

        I.source, I.filename, I.entry, I.interactionid,

        -- Specific experiment details.

        pmid, reftype, interactiondetectiontype,

        -- General interaction and interactor details providing bait information.

        I.rig, B.rog

    from tmp_source_interactions as I
    inner join xml_experiments as E
        on (I.source, I.filename, I.entry, I.interactionid)
         = (E.source, E.filename, E.entry, E.interactionid)
    inner join tmp_source_experiments as ES
        on (E.source, E.filename, E.entry, E.experimentid)
         = (ES.source, ES.filename, ES.entry, ES.experimentid)
    left outer join tmp_bait_interactors as B
        on (I.source, I.filename, I.entry, I.interactionid)
         = (B.source, B.filename, B.entry, B.interactionid);

create index tmp_source_interaction_experiments_index on tmp_source_interaction_experiments(source, filename, entry, interactionid);
analyze tmp_source_interaction_experiments;

create temporary table tmp_source_databases as

    -- Get all databases represented by interactors.
    -- Compatibility between identifiers and databases is maintained in the
    -- import_irefindex_sequences.sql template.

    select distinct
        lower(I.dblabel) as labelname,                             -- used to match labels in the data
        coalesce(lower(M.source), lower(I.dblabel)) as sourcename, -- used as the final source name
        M.releasedate as release_date,
        M.version as release_label,
        M.downloadfiles as comments
    from xml_xref_all_interactors as I
    left outer join irefindex_manifest as M
        on lower(I.dblabel) = lower(M.source)
        or (I.dblabel = 'uniprotkb' or I.dblabel in ('SP', 'Swiss-Prot', 'TREMBL')) and M.source = 'UNIPROT'
        or I.dblabel = 'flybase' and M.source = 'FLY'
        or I.dblabel = 'cygd' and M.source = 'YEAST'
        or I.dblabel = 'sgd' and M.source = 'YEAST'
        or I.dblabel = 'ddbj/embl/genbank' and M.source = 'GENPEPT'
        or I.dblabel like '%pdb' and M.source = 'PDB'
        or (I.dblabel like 'entrezgene%' or I.dblabel like 'entrez gene%') and M.source = 'GENE'

    -- Get all other source databases.

    union all
    select distinct
        lower(M.source) as labelname,
        lower(M.source) as sourcename,
        M.releasedate as release_date,
        M.version as release_label,
        M.downloadfiles as comments
    from irefindex_manifest as M
    left outer join xml_xref_all_interactors as I
        on lower(M.source) = lower(I.dblabel)
    where I.dblabel is null

    -- Add aliases for MPI-LIT and MPI-IMEX.

    union all
    select
        'mpi-lit' as labelname,
        lower(M.source) as sourcename,
        M.releasedate as release_date,
        M.version as release_label,
        M.downloadfiles as comments
    from irefindex_manifest as M
    where M.source = 'MPIDB'
    union all
    select
        'mpi-imex' as labelname,
        lower(M.source) as sourcename,
        M.releasedate as release_date,
        M.version as release_label,
        M.downloadfiles as comments
    from irefindex_manifest as M
    where M.source = 'MPIDB'

    -- Add the invented rogid label.

    union all
    select
        'rogid' as labelname,
        'rogid' as sourcename,
        null as release_date,
        null as release_label,
        null as comments;

analyze tmp_source_databases;



-- -----------------------------------------------------------------------------
-- Enumeration tables.

create temporary sequence tmp_num_source_interactions_id minvalue 1;

create temporary table tmp_num_source_interactions as
    select
        nextval('tmp_num_source_interactions_id') as id,
        source, filename, entry, interactionid
    from tmp_source_interactions
    group by source, filename, entry, interactionid;

alter table tmp_num_source_interactions add primary key(source, filename, entry, interactionid);

analyze tmp_num_source_interactions;

-- A numbered version of the sources.

create temporary sequence tmp_num_source_databases_id minvalue 1;

create temporary table tmp_num_source_databases as
    select
        nextval('tmp_num_source_databases_id') as id,
        sourcename
    from tmp_source_databases
    group by sourcename;

analyze tmp_num_source_databases;



-- -----------------------------------------------------------------------------
-- Export tables.

create temporary sequence tmp_irefweb_interaction_type_id minvalue 1;

create temporary table tmp_irefweb_interaction_type as
    select
        nextval('tmp_irefweb_interaction_type_id') as id,
        0 as version,
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

    group by T.code, T.name, G.code;

create temporary sequence tmp_irefweb_interaction_detection_type_id minvalue 1;

create temporary table tmp_irefweb_interaction_detection_type as
    select
        nextval('tmp_irefweb_interaction_detection_type_id') as id,
        0 as version,
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

    group by T.code, T.name;

create temporary sequence tmp_irefweb_interactor_detection_type_id minvalue 1;

create temporary table tmp_irefweb_interactor_detection_type as
    select
        nextval('tmp_irefweb_interactor_detection_type_id') as id,
        0 as version,
        coalesce(min(S.name), T.name) as name,
        'interactor detection method - ' || T.name as description,
        T.code as psi_mi_code

    from xml_xref_participants as I
    inner join psicv_terms as T
        on I.refvalue = T.code
        and T.nametype = 'preferred'
    left outer join psicv_terms as S
        on I.refvalue = S.code
        and S.nametype = 'synonym'
        and S.qualifier = 'PSI-MI-short'

    group by T.code, T.name;

analyze tmp_irefweb_interactor_detection_type;

create temporary sequence tmp_irefweb_interactor_type_id minvalue 1;

create temporary table tmp_irefweb_interactor_type as
    select
        nextval('tmp_irefweb_interactor_type_id') as id,
        0 as version,
        interactortype as name
    from tmp_source_interactors as I
    where interactortype is not null
    group by interactortype;

create temporary table tmp_irefweb_source_db as
    select distinct
        id,
        0 as version,
        S.sourcename as name,
        release_date,
        release_label,
        comments
    from tmp_source_databases as S
    inner join tmp_num_source_databases as N
        on S.sourcename = N.sourcename;

create temporary sequence tmp_irefweb_name_space_id minvalue 1;

create temporary table tmp_irefweb_name_space as
    select
        nextval('tmp_irefweb_name_space_id') as id,
        0 as version,
        name,
        cast(id as varchar) as source_db_id
    from tmp_irefweb_source_db;

-- NOTE: Need to complement this with xml_name information.

insert into tmp_irefweb_name_space
    (id, version, name, source_db_id)
    values (nextval('tmp_irefweb_name_space_id'), 0, 'Short label', null);
insert into tmp_irefweb_name_space
    (id, version, name, source_db_id)
    values (nextval('tmp_irefweb_name_space_id'), 0, 'Full name', null);
insert into tmp_irefweb_name_space
    (id, version, name, source_db_id)
    values (nextval('tmp_irefweb_name_space_id'), 0, 'Alias', null);
insert into tmp_irefweb_name_space
    (id, version, name, source_db_id)
    values (nextval('tmp_irefweb_name_space_id'), 0, 'Display name', null);
insert into tmp_irefweb_name_space
    (id, version, name, source_db_id)
    values (nextval('tmp_irefweb_name_space_id'), 0, 'Annotations', null);

create index tmp_irefweb_name_space_index on tmp_irefweb_name_space(name, source_db_id);

analyze tmp_irefweb_name_space;

create temporary table tmp_irefweb_interaction as
    select
        I.rig as id,
        0 as version,
        I.rig as rig,
        I.rigid as rigid,
        'Interaction involving ' || D.description as name,
        cast(null as varchar) as description,
        H.score as hpr,
        L.score as lpr,
        N.score as np

    from tmp_source_interactions as I
    inner join tmp_interaction_descriptions as D
        on I.rigid = D.rigid

    -- Add interaction score information.

    left outer join irefindex_confidence as H
        on I.rigid = H.rigid
        and H.scoretype = 'hpr'
    left outer join irefindex_confidence as L
        on I.rigid = L.rigid
        and L.scoretype = 'lpr'
    left outer join irefindex_confidence as N
        on I.rigid = N.rigid
        and N.scoretype = 'np'
    group by I.rigid, I.rig, D.description, H.score, L.score, N.score;

-- -----------------------------------------------------------------------------
-- Work tables.

create temporary table tmp_rogid_identifiers as
    select rogid, acc[2] as dblabel, acc[3] as refvalue
    from (

        -- Choose the highest priority identifiers.

        select rogid,
            min(array[priority, dblabel, refvalue]) as acc
        from (

            -- Obtain "mapped" identifiers for proteins (with priority "A")
            -- and gene identifiers (with priority "C"), ignoring original
            -- identifiers. Identifiers are then reclassified.

            select rogid, dblabel, refvalue,
                case when dblabel = 'uniprotkb' then 'AA'
                     when dblabel = 'entrezgene/locuslink' then 'AB'
                     when dblabel = 'refseq' then 'AC'
                     when dblabel = 'pdb' then 'AD'
                     else 'AE'
                end as priority
            from irefindex_rogid_identifiers
            where priority in ('A', 'C')

            ) as X

        group by rogid

        ) as X;

analyze tmp_rogid_identifiers;

create temporary table tmp_display_aliases as

    -- Prefer Swiss-Prot identifiers to gene symbols to other identifiers.
    -- Without any of these, the integer identifier is used.

    select I.rog, I.rogid, coalesce(
        min(uniprotid), min(symbol), P.refvalue, cast(I.rog as varchar)
        ) as refvalue,
        cast('Display name' as varchar) as dblabel
    from tmp_source_interactors as I

    -- UniProt identifiers originating from Swiss-Prot.

    left outer join tmp_uniprot_rogids as U
        on I.rogid = U.rogid
        and U.source = 'Swiss-Prot'

    -- Obtain another identifier as the display alias if no suitable UniProt
    -- identifier can be found.

    left outer join tmp_rogid_identifiers as P
        on I.rogid = P.rogid
        and P.dblabel <> 'rogid'

        -- Exclude GenBank-related RefSeq entries.

        and not (P.dblabel in ('genbank_protein_gi', 'refseq') and not P.refvalue ~ '^[A-Z][A-Z]_[0-9]+$')

    -- Gene symbols are chosen where RefSeq protein identifiers are suggested.

    left outer join irefindex_gene2rog as G
        on I.rogid = G.rogid
        and P.dblabel = 'refseq'
    left outer join gene_info as GI
        on G.geneid = GI.geneid

    group by I.rog, I.rogid, P.refvalue;

analyze tmp_display_aliases;

-- Related aliases aggregate aliases for specific (non-canonical) interactors.

create temporary table tmp_related_aliases as
    select rog, I.rogid, uniprotid as refvalue, dblabel
    from tmp_source_interactors as I
    inner join irefindex_rogids_canonical as C
        on I.rogid = C.crogid
    inner join irefindex_rogid_identifiers as R
        on C.rogid = R.rogid
    inner join uniprot_accessions
        on dblabel = 'uniprotkb'
        and refvalue = accession
    union all
    select rog, I.rogid, symbol as refvalue, dblabel
    from tmp_source_interactors as I
    inner join irefindex_rogids_canonical as C
        on I.rogid = C.crogid
    inner join irefindex_rogid_identifiers as R
        on C.rogid = R.rogid
    inner join gene_info
        on dblabel = 'entrezgene/locuslink'
        and cast(refvalue as integer) = geneid;

analyze tmp_related_aliases;

-- Other aliases are generated from name information.

create temporary table tmp_name_aliases as
    select distinct rog, rogid, name as refvalue,
        cast(case nametype
            when 'shortLabel' then 'Short label'
            when 'fullName'   then 'Full name'
            when 'alias'      then 'Alias'
            else nametype
        end as varchar) as dblabel
    from tmp_source_interactors as I
    inner join xml_names_interactor_names as N
        on (I.source, I.filename, I.entry, I.interactorid)
         = (N.source, N.filename, N.entry, N.interactorid);

analyze tmp_name_aliases;

-- The combined aliases.

create temporary table tmp_aliases as
    select distinct rog, rogid, refvalue, dblabel
    from (
        select rog, rogid, originalrefvalue as refvalue, originaldblabel as dblabel
        from tmp_source_interactors
        union
        select rog, rogid, finalrefvalue as refvalue, finaldblabel as dblabel
        from tmp_source_interactors
        union
        select rog, rogid, primaryrefvalue as refvalue, primarydblabel as dblabel
        from tmp_source_interactors
        where primaryrefvalue is not null
        union
        select rog, rogid, canonicalrefvalue as refvalue, canonicaldblabel as dblabel
        from tmp_source_interactors
        union
        select rog, rogid, refvalue, dblabel
        from tmp_related_aliases

        -- Add special aliases.

        union all
        select rog, rogid, refvalue, dblabel
        from tmp_display_aliases
        union all
        select rog, rogid, refvalue, dblabel
        from tmp_name_aliases
        ) as X;

create index tmp_aliases_index on tmp_aliases(dblabel, refvalue);

analyze tmp_aliases;

create temporary table tmp_current_sequences as

    -- Sequences from current databases.

    select distinct "sequence", actualsequence, dblabel as sourcedb
    from irefindex_sequences_original as S
    inner join irefindex_distinct_interactions_canonical as C
        on S.sequence = substring(C.rogid for 27)

    -- Sequences from archived data.

    union
    select "sequence", actualsequence, dblabel as sourcedb
    from irefindex_sequences_archived_original as S
    inner join irefindex_distinct_interactions_canonical as C
        on S.sequence = substring(C.rogid for 27)

    -- Sequences from interaction records.

    union
    select distinct S.sequence, actualsequence, source as sourcedb
    from xml_sequences_original as S
    inner join xml_sequences as X
        on S.sequence = X.sequence
    inner join irefindex_distinct_interactions_canonical as C
        on S.sequence = substring(C.rogid for 27);

analyze tmp_current_sequences;

-- -----------------------------------------------------------------------------
-- Export tables.

create temporary sequence tmp_irefweb_sequence_id minvalue 1;

create temporary table tmp_irefweb_sequence as
    select nextval('tmp_irefweb_sequence_id') as id,
        0 as version,
        S.sequence as seguid,
        actualsequence as "sequence"
    from tmp_current_sequences as S
    group by S.sequence, actualsequence;

create index tmp_irefweb_sequence_index on tmp_irefweb_sequence(seguid);

analyze tmp_irefweb_sequence;

create temporary sequence tmp_irefweb_sequence_source_db_id minvalue 1;

create temporary table tmp_irefweb_sequence_source_db as
    select
        nextval('tmp_irefweb_sequence_source_db_id') as id,
        0 as version,
        S.id as source_db_sqnc_id,
        S.id as sequence_id,
        min(N.id) as source_db_id
    from tmp_current_sequences as C
    inner join tmp_irefweb_sequence as S
        on C.sequence = S.seguid
    inner join tmp_source_databases as SD
        on lower(sourcedb) = SD.labelname
    inner join tmp_num_source_databases as N
        on SD.sourcename = N.sourcename
    group by S.id;

create temporary sequence tmp_irefweb_alias_id minvalue 1;

create temporary table tmp_irefweb_alias as
    select nextval('tmp_irefweb_alias_id') as id,
        0 as version,
        refvalue as alias,
        NS.id as name_space_id
    from tmp_aliases as A
    inner join tmp_source_databases as SD
        on A.dblabel = SD.labelname
    inner join tmp_irefweb_name_space as NS
        on SD.sourcename = NS.name
    where A.dblabel not in ('Display name', 'Short label', 'Full name', 'Alias')
    group by refvalue, NS.id
    union all
    select nextval('tmp_irefweb_alias_id') as id,
        0 as version,
        refvalue as alias,
        NS.id as name_space_id
    from tmp_aliases as A
    inner join tmp_irefweb_name_space as NS
        on A.dblabel = NS.name
    where A.dblabel in ('Display name', 'Short label', 'Full name', 'Alias')
    group by refvalue, NS.id;

create index tmp_irefweb_alias_index on tmp_irefweb_alias(alias, name_space_id);

analyze tmp_irefweb_alias;

create temporary sequence tmp_irefweb_interactor_alias_id minvalue 1;

create temporary table tmp_irefweb_interactor_alias as
    select nextval('tmp_irefweb_interactor_alias_id') as id,
        0 as version,
        X.rog as interactor_id,
        A.id as alias_id
    from tmp_aliases as X
    inner join tmp_source_databases as SD
        on X.dblabel = SD.labelname
    inner join tmp_irefweb_name_space as NS
        on SD.sourcename = NS.name
    inner join tmp_irefweb_alias as A
        on X.refvalue = A.alias
        and NS.id = A.name_space_id
    where X.dblabel not in ('Display name', 'Short label', 'Full name', 'Alias')
    group by X.rog, A.id
    union all
    select nextval('tmp_irefweb_interactor_alias_id') as id,
        0 as version,
        X.rog as interactor_id,
        A.id as alias_id
    from tmp_aliases as X
    inner join tmp_irefweb_name_space as NS
        on X.dblabel = NS.name
    inner join tmp_irefweb_alias as A
        on X.refvalue = A.alias
        and NS.id = A.name_space_id
    where X.dblabel in ('Display name', 'Short label', 'Full name', 'Alias');

create index tmp_irefweb_interactor_alias_index on tmp_irefweb_interactor_alias(interactor_id);

analyze tmp_irefweb_interactor_alias;

create temporary table tmp_irefweb_interactor as
    select distinct
        I.rog,
        I.rogid,
        I.seguid,
        I.taxid as taxonomy_id,
        (select id from tmp_irefweb_interactor_type where name = 'protein') as interactor_type_id,
        IA.id as display_interactor_alias_id,
        S.id as sequence_id,
        I.rog as id,
        0 as version

    from tmp_source_interactors as I

    -- Need to choose only one alias, preferably a UniProt identifier.

    inner join tmp_irefweb_interactor_alias as IA
        on I.rog = IA.interactor_id
    inner join tmp_irefweb_alias as A
        on A.id = IA.alias_id
        and A.name_space_id = (select id from tmp_irefweb_name_space where name = 'Display name')

    -- Archived sequences can be missing.

    left outer join tmp_irefweb_sequence as S
        on I.seguid = S.seguid;

-- NOTE: This appears to be a summary table presenting aliases alongside related
-- NOTE: information.

create temporary table tmp_irefweb_interactor_alias_display as
    select interactor_id as rog, alias, name_space_id, alias_id, interactor_id, IA.id as interactor_alias_id
    from tmp_irefweb_interactor_alias as IA
    inner join tmp_irefweb_alias as A
        on IA.alias_id = A.id
    where A.name_space_id = (select id from tmp_irefweb_name_space where name = 'Display name');

create temporary sequence tmp_irefweb_interaction_interactor_id minvalue 1;

create temporary table tmp_irefweb_interaction_interactor as
    select
        nextval('tmp_irefweb_interaction_interactor_id') as id,
        0 as version,
        rig as interaction_id,
        rog as interactor_id,
        count(rog) as cardinality
    from irefindex_distinct_interactions_canonical as C
    inner join irefindex_rog2rogid as I
        on C.rogid = I.rogid
    inner join irefindex_rig2rigid as I2
        on C.rigid = I2.rigid
    group by rig, rog;

create index tmp_irefweb_interaction_interactor_index on tmp_irefweb_interaction_interactor(interaction_id, interactor_id);

analyze tmp_irefweb_interaction_interactor;

-- Note that multiple source records can appear to refer to the same source
-- interaction information. Arbitrary identifiers are also created where no
-- usable source interaction identifiers are provided.

-- NOTE: Here, interaction types are null if not known. iRefWeb 9 data employs
-- NOTE: a separate, special interaction type record to denote an "unknown"
-- NOTE: type.

create temporary table tmp_irefweb_interaction_source_db as
    select distinct
        N.id as id,
        0 as version,
        I.rig as interaction_id,
        coalesce(I.refvalue, I.filename || '/' || I.entry || '/' || I.interactionid) as source_db_intrctn_id,
        SN.id as source_db_id,
        T.id as interaction_type_id
    from tmp_source_interactions as I
    inner join tmp_num_source_interactions as N
        on (I.source, I.filename, I.entry, I.interactionid)
         = (N.source, N.filename, N.entry, N.interactionid)
    inner join tmp_source_databases as S
        on lower(I.source) = S.labelname
    inner join tmp_num_source_databases as SN
        on S.sourcename = SN.sourcename
    left outer join tmp_irefweb_interaction_type as T
        on I.interactiontype = T.psi_mi_code;

create temporary sequence tmp_irefweb_interaction_source_db_experiment_id minvalue 1;

create temporary table tmp_irefweb_interaction_source_db_experiment as
    select
        nextval('tmp_irefweb_interaction_source_db_experiment_id') as id,
        0 as version,
        N.id as interaction_source_db_id,
        II.id as bait_interaction_interactor_id,
        E.pmid as pubmed_id,
        IDT.id as interaction_detection_type_id,
        case when E.reftype = 'secondaryRef' then 1 else 0 end as isSecondary
    from tmp_source_interaction_experiments as E
    inner join tmp_num_source_interactions as N
        on (E.source, E.filename, E.entry, E.interactionid)
         = (N.source, N.filename, N.entry, N.interactionid)
    left outer join tmp_irefweb_interaction_interactor as II
        on E.rig = II.interaction_id
        and E.rog = II.interactor_id
    left outer join tmp_irefweb_interaction_detection_type as IDT
        on E.interactiondetectiontype = IDT.psi_mi_code;

create temporary sequence tmp_irefweb_score_id minvalue 1;

create temporary table tmp_irefweb_score as
    select
        nextval('tmp_irefweb_score_id') as id,
        0 as version,
        code,
        cast('' as varchar) as description
    from tmp_source_interactors
    group by code;

analyze tmp_irefweb_score;

-- -----------------------------------------------------------------------------
-- Work tables.

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
    from tmp_irefweb_score;

analyze tmp_score_values;

create temporary table tmp_canonical_scores as
    select rogid, code
    from (
        select rogid, min(value) as value
        from tmp_source_interactors as I
        inner join tmp_score_values as S
            on I.code = S.code
        group by rogid
        ) as X
    inner join tmp_score_values as S
        on X.value = S.value;

alter table tmp_canonical_scores add primary key(rogid, code);

analyze tmp_canonical_scores;

-- -----------------------------------------------------------------------------
-- Export tables.

create temporary sequence tmp_irefweb_interaction_interactor_assignment_id minvalue 1;

create temporary table tmp_irefweb_interaction_interactor_assignment as
    select
        nextval('tmp_irefweb_interaction_interactor_assignment_id') as id,
        0 as version,
        II.id as interaction_interactor_id,
        N.id as interaction_source_db_id,
        T.id as interactor_detection_type_id,
        PA.id as primary_alias_id,
        UA.id as used_alias_id,
        FA.id as final_alias_id,
        CA.id as canonical_alias_id,
        I.primarytaxid as primary_taxonomy_id,
        I.originaltaxid as used_taxonomy_id,
        I.taxid as final_taxonomy_id,
        X.index as position_as_found_in_source_db,
        S.id as score_id,
        S2.id as canonical_score_id

    from tmp_source_participants as X
    inner join tmp_source_interactors as I
        on (X.source, X.filename, X.entry, X.interactorid)
         = (I.source, I.filename, I.entry, I.interactorid)
    inner join tmp_source_interactions as I2
        on (X.source, X.filename, X.entry, X.interactionid)
         = (I2.source, I2.filename, I2.entry, I2.interactionid)
    inner join tmp_num_source_interactions as N
        on (X.source, X.filename, X.entry, X.interactionid)
         = (N.source, N.filename, N.entry, N.interactionid)
    inner join tmp_irefweb_interaction_interactor as II
        on I2.rig = II.interaction_id
        and I.rog = II.interactor_id
    left outer join tmp_irefweb_interactor_detection_type as T
        on X.interactordetectiontype = T.psi_mi_code

    -- Used alias.

    inner join tmp_source_databases as USD
        on I.originaldblabel = USD.labelname
    inner join tmp_irefweb_name_space as UNS
        on USD.sourcename = UNS.name
    inner join tmp_irefweb_alias as UA
        on I.originalrefvalue = UA.alias
        and UNS.id = UA.name_space_id

    -- Final alias.

    inner join tmp_source_databases as FSD
        on I.finaldblabel = FSD.labelname
    inner join tmp_irefweb_name_space as FNS
        on FSD.sourcename = FNS.name
    inner join tmp_irefweb_alias as FA
        on I.finalrefvalue = FA.alias
        and FNS.id = FA.name_space_id

    -- Primary alias.

    left outer join tmp_source_databases as PSD
        on I.primarydblabel = PSD.labelname
    left outer join tmp_irefweb_name_space as PNS
        on PSD.sourcename = PNS.name
    left outer join tmp_irefweb_alias as PA
        on I.primaryrefvalue = PA.alias
        and PNS.id = PA.name_space_id

    -- Canonical alias.

    inner join tmp_source_databases as CSD
        on I.canonicaldblabel = CSD.labelname
    inner join tmp_irefweb_name_space as CNS
        on CSD.sourcename = CNS.name
    inner join tmp_irefweb_alias as CA
        on I.canonicalrefvalue = CA.alias
        and CNS.id = CA.name_space_id

    -- Scores.

    inner join tmp_irefweb_score as S
        on I.code = S.code
    inner join tmp_canonical_scores as CS
        on I.rogid = CS.rogid
    inner join tmp_irefweb_score as S2
        on CS.code = S2.code;

-- Note that iRefIndex 9 employed an arbitrary sequence number for the RGG
-- identifier whereas iRefIndex 10 and later use the smallest gene identifier in
-- the related gene group.

create temporary table tmp_irefweb_geneid2rog as
    select distinct R.rggid as rgg, geneid, II.rog, R.rogid, II.rog as interactor_id
    from irefindex_rgg_rogids_canonical as R
    inner join irefindex_rgg_genes as G
        on R.rggid = G.rggid

    -- Restrict to interactors participating in interactions.

    inner join irefindex_distinct_interactions_canonical as I
        on R.rogid = I.rogid
    inner join irefindex_rog2rogid as II
        on I.rogid = II.rogid;

-- -----------------------------------------------------------------------------
-- Work tables.

-- NOTE: Statistics are similar to those in reports/interactions_by_source.sql.

create temporary table tmp_interactions_available_by_source as
    select source, count(distinct array[filename, cast(entry as varchar), interactionid]) as total
    from xml_interactors
    group by source;

analyze tmp_interactions_available_by_source;

create temporary table tmp_interactions_having_assignments as
    select I.source, count(*) as total
    from (

        -- Group interactors by interaction and make sure that only interactions
        -- where all interactors provide sequences are considered.

        select I.source, I.filename, I.entry, I.interactionid
        from xml_interactors as I
        left outer join xml_xref_interactor_sequences as S
            on (I.source, I.filename, I.entry, I.interactorid) =
               (S.source, S.filename, S.entry, S.interactorid)
        group by I.source, I.filename, I.entry, I.interactionid
        having count(I.interactorid) = count(S.interactorid)
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

-- -----------------------------------------------------------------------------
-- Export tables.

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

-- -----------------------------------------------------------------------------
-- Output export tables.

\copy tmp_irefweb_alias                             to '<directory>/irefweb_alias'
\copy tmp_irefweb_geneid2rog                        to '<directory>/irefweb_geneid2rog'
\copy tmp_irefweb_interaction                       to '<directory>/irefweb_interaction'
\copy tmp_irefweb_interaction_detection_type        to '<directory>/irefweb_interaction_detection_type'
\copy tmp_irefweb_interaction_interactor            to '<directory>/irefweb_interaction_interactor'
\copy tmp_irefweb_interaction_interactor_assignment to '<directory>/irefweb_interaction_interactor_assignment'
\copy tmp_irefweb_interaction_source_db             to '<directory>/irefweb_interaction_source_db'
\copy tmp_irefweb_interaction_source_db_experiment  to '<directory>/irefweb_interaction_source_db_experiment'
\copy tmp_irefweb_interaction_type                  to '<directory>/irefweb_interaction_type'
\copy tmp_irefweb_interactor                        to '<directory>/irefweb_interactor'
\copy tmp_irefweb_interactor_alias                  to '<directory>/irefweb_interactor_alias'
\copy tmp_irefweb_interactor_alias_display          to '<directory>/irefweb_interactor_alias_display'
\copy tmp_irefweb_interactor_detection_type         to '<directory>/irefweb_interactor_detection_type'
\copy tmp_irefweb_interactor_type                   to '<directory>/irefweb_interactor_type'
\copy tmp_irefweb_name_space                        to '<directory>/irefweb_name_space'
\copy tmp_irefweb_score                             to '<directory>/irefweb_score'
\copy tmp_irefweb_sequence                          to '<directory>/irefweb_sequence'
\copy tmp_irefweb_sequence_source_db                to '<directory>/irefweb_sequence_source_db'
\copy tmp_irefweb_source_db                         to '<directory>/irefweb_source_db'
\copy tmp_irefweb_statistics                        to '<directory>/irefweb_statistics'

rollback;
