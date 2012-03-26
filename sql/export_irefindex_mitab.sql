begin;

-- Create a table of interactor pairs for each source database interaction.
-- Although one could group records according to the rigid and uidA, uidB pairs,
-- producing a consolidated table of interaction components, the data remains
-- specific to the source interaction information so that related information
-- (such as experimental details) can be associated specifically with a
-- particular source record.
--
-- For interactions with one or two participants, a single line is written:
--
-- One participant, A:         uidA = A, uidB = A
-- Two participants, A and B:  uidA = A, uidB = B
--
-- For interactions with more than two participants (complexes), as many lines
-- are written as participants:
--
-- Many participants, A...N:   uidA = rigid, uidB = A; ...; uidA = rigid, uidB = N

create temporary table tmp_interactions as

    -- One participant.

    select I.source, I.filename, I.entry, I.interactionid, rigid,
        interactorid as interactoridA, interactorid as interactoridB,
        participantid as participantidA, participantid as participantidB,
        rogid as uidA, rogid as uidB,
        cast('Y' as varchar) as edgetype, numParticipants
    from irefindex_interactions as I
    inner join (
        select source, filename, entry, interactionid, count(participantid) as numParticipants
        from irefindex_interactions
        group by source, filename, entry, interactionid
        having count(participantid) = 1
        ) as Y
        on (I.source, I.filename, I.entry, I.interactionid) = (Y.source, Y.filename, Y.entry, Y.interactionid)
    union all

    -- Two participants.

    select I.source, I.filename, I.entry, I.interactionid, rigid,
        detailsA[2] as interactoridA, detailsB[2] as interactoridB,
        detailsA[3] as participantidA, detailsB[3] as participantidB,
        detailsA[1] as uidA, detailsB[1] as uidB,
        cast('X' as varchar) as edgetype, numParticipants
    from (
        select source, filename, entry, interactionid, rigid, count(participantid) as numParticipants,
            min(array[rogid, interactorid, participantid]) as detailsA,
            max(array[rogid, interactorid, participantid]) as detailsB
        from irefindex_interactions
        group by source, filename, entry, interactionid, rigid
        having count(participantid) = 2
        ) as I
    union all

    -- Many participants.

    select I.source, I.filename, I.entry, I.interactionid, rigid,
        cast(null as varchar) as interactoridA, interactorid as interactoridB,
        cast(null as varchar) as participantidA, participantid as participantidB,
        rigid as uidA, rogid as uidB,
        cast('C' as varchar) as edgetype, numParticipants
    from irefindex_interactions as I
    inner join (
        select source, filename, entry, interactionid, count(participantid) as numParticipants
        from irefindex_interactions
        group by source, filename, entry, interactionid
        having count(participantid) > 2
        ) as C
        on (I.source, I.filename, I.entry, I.interactionid) = (C.source, C.filename, C.entry, C.interactionid);

analyze tmp_interactions;

-- Define all source database identifiers for each ROG identifier.

create temporary table tmp_identifiers as
    select rogid, array_accum(distinct dblabel || ':' || refvalue) as names
    from irefindex_rogid_identifiers
    group by rogid;

analyze tmp_identifiers;

-- Define the preferred identifiers as those provided by UniProt or RefSeq, with
-- ROG identifiers used otherwise.

create temporary table tmp_preferred as
    select I.rogid,
        coalesce(min(U.dblabel), min(R.dblabel), 'rogid') as dblabel,
        coalesce(min(U.refvalue), min(R.refvalue), I.rogid) as refvalue
    from irefindex_rogids as I
    left outer join irefindex_rogid_identifiers as U
        on I.rogid = U.rogid
        and U.dblabel = 'uniprotkb'
    left outer join irefindex_rogid_identifiers as R
        on I.rogid = R.rogid
        and R.dblabel = 'refseq'
    group by I.rogid;

analyze tmp_preferred;

-- Define aliases for each ROG identifier.

create temporary table tmp_aliases as
    select rogid, array_accum(distinct dblabel || ':' || refvalue) as aliases
    from (
        select rogid, dblabel, uniprotid as refvalue
        from irefindex_rogid_identifiers
        inner join uniprot_accessions
            on dblabel = 'uniprotkb'
            and refvalue = accession
        union all
        select rogid, dblabel, cast(geneid as varchar) as refvalue
        from irefindex_rogid_identifiers
        inner join gene_info
            on dblabel = 'entrezgene'
            and cast(refvalue as integer) = geneid
        ) as X
    group by rogid;

analyze tmp_aliases;

-- Accumulate role collections.
-- Each role is encoded as "MI:NNNN(...)".

create temporary table tmp_participants as
    select source, filename, entry, participantid, property, array_accum(distinct refvalue || '(' || coalesce(name, '-') || ')') as refvalues
    from xml_xref_participants
    left outer join psicv_terms
        on refvalue = code
    group by source, filename, entry, participantid, property;

alter table tmp_participants add primary key(source, filename, entry, participantid, property);
analyze tmp_participants;

-- Accumulate methods.
-- Each role is encoded as "MI:NNNN(...)".

create temporary table tmp_methods as
    select source, filename, entry, experimentid, property, array_accum(distinct refvalue || '(' || coalesce(name, '-') || ')') as refvalues
    from xml_xref_experiment_methods
    left outer join psicv_terms
        on refvalue = code
    group by source, filename, entry, experimentid, property;

alter table tmp_methods add primary key(source, filename, entry, experimentid, property);
analyze tmp_methods;

-- Accumulate PubMed identifiers.

create temporary table tmp_pubmed as
    select source, filename, entry, experimentid, array_accum(distinct refvalue) as refvalues
    from xml_xref_experiment_pubmed
    group by source, filename, entry, experimentid;

alter table tmp_pubmed add primary key(source, filename, entry, experimentid);
analyze tmp_pubmed;

-- Consolidate assignment information to get full details of preferred assignments.

create temporary table tmp_assignments as
    select A.*, score
    from irefindex_assignments_preferred as P
    inner join irefindex_assignments as A
        on (P.source, P.filename, P.entry, P.interactorid, P.sequencelink, P.dblabel, P.refvalue) =
           (A.source, A.filename, A.entry, A.interactorid, A.sequencelink, A.dblabel, A.refvalue)
    inner join irefindex_assignment_scores as S
        on (P.source, P.filename, P.entry, P.interactorid) = (S.source, S.filename, S.entry, S.interactorid);

alter table tmp_assignments add primary key(source, filename, entry, interactorid);
analyze tmp_assignments;

-- Collect all interaction-related information.

create temporary table tmp_named_interactions as
    select I.*,

        -- interactionIdentifier (includes rigid, irigid, and edgetype as "X", "Y" or "C")

        case when nameI.dblabel is null then ''
             else nameI.dblabel || ':' || nameI.refvalue || '|'
        end || 'rigid:' || I.rigid || '|edgetype:' || I.edgetype as interactionIdentifier,

        -- sourcedb (as "MI:code(name)" using "MI:0000(name)" for non-CV sources)

        coalesce(sourceI.code, 'MI:0000') || '(' || coalesce(sourceI.name, lower(I.source)) || ')' as sourcedb

    from tmp_interactions as I
    left outer join xml_xref_interactions as nameI
        on (I.source, I.filename, I.entry, I.interactionid) = (nameI.source, nameI.filename, nameI.entry, nameI.interactionid)
    left outer join psicv_terms as sourceI
        on lower(I.source) = sourceI.name;

analyze tmp_named_interactions;

-- Combine interaction and experiment information.

create temporary table tmp_interaction_experiments as
    select I.*,

        -- hostOrganismTaxid (as "taxid:...")

        case when taxidE is null then '-'
             else 'taxid:' || taxidE.taxid || '(' || coalesce(taxnamesE.name, '-') || ')'
        end as hostOrganismTaxid,

        -- method (interaction detection method as "MI:code(name)")

        case when methodE.refvalues is null or array_length(methodE.refvalues, 1) = 0 then '-'
             else array_to_string(methodE.refvalues, '|')
        end as method,

        -- pmids (as "pubmed:...")

        case when pubmedE.refvalues is null or array_length(pubmedE.refvalues, 1) = 0 then '-'
             else array_to_string(pubmedE.refvalues, '|')
        end as pmids

    from tmp_named_interactions as I
    inner join xml_experiments as E
        on (I.source, I.filename, I.entry, I.interactionid) = (E.source, E.filename, E.entry, E.interactionid)

    -- Host organism.

    left outer join xml_xref_experiment_organisms as taxidE
        on (I.source, I.filename, I.entry, E.experimentid) = (taxidE.source, taxidE.filename, taxidE.entry, taxidE.experimentid)
    left outer join taxonomy_names as taxnamesE
        on taxidE.taxid = taxnamesE.taxid
        and taxnamesE.nameclass = 'scientific name'

    -- Interaction detection method.

    left outer join tmp_methods as methodE
        on (I.source, I.filename, I.entry, E.experimentid) = (methodE.source, methodE.filename, methodE.entry, methodE.experimentid)
        and methodE.property = 'interactionDetectionMethod'

    -- PubMed identifiers.

    left outer join tmp_pubmed as pubmedE
        on (I.source, I.filename, I.entry, E.experimentid) = (pubmedE.source, pubmedE.filename, pubmedE.entry, pubmedE.experimentid);

analyze tmp_interaction_experiments;

-- Combine interactor information.

create temporary table tmp_interactor_experiments as
    select I.*,

        -- finalReferenceA (the original reference for A, or a corrected/complete/updated/unambiguous reference)
        -- NOTE: This actually appears as "-" in the iRefIndex 9 MITAB output for complexes.

        case when edgetype = 'C' then 'complex:' || I.rigid
             else nameA.dblabel || ':' || nameA.refvalue
        end as finalReferenceA,

        -- finalReferenceB (the original reference for B, or a corrected/complete/updated/unambiguous reference)

        nameB.dblabel || ':' || nameB.refvalue as finalReferenceB,

        -- originalReferenceA (original primary or secondary reference for A, the rigid of any complex as 'complex:...')
        -- NOTE: This actually appears as "-" in the iRefIndex 9 MITAB output for complexes.

        case when edgetype = 'C' then 'complex:' || I.rigid
             else nameA.originaldblabel || ':' || nameA.originalrefvalue
        end as originalReferenceA,

        -- originalReferenceB (original primary or secondary reference for B)

        nameB.originaldblabel || ':' || nameB.originalrefvalue as originalReferenceB,

        -- taxA (as "taxid:...")

        case when edgetype = 'C' then '-'
             else 'taxid:' || nameA.taxid || '(' || coalesce(taxnamesA.name, '-') || ')'
        end as taxA,

        -- taxB (as "taxid:...")

        'taxid:' || nameB.taxid || '(' || coalesce(taxnamesB.name, '-') || ')' as taxB,

        -- mappingScoreA (operation characters describing the original-to-final transformation, "-" for complexes)

        case when edgetype = 'C' then '-' else nameA.score end as mappingScoreA,

        -- mappingScoreB (operation characters describing the original-to-final transformation)

        nameB.score as mappingScoreB

    from tmp_interaction_experiments as I

    -- Information for interactor A.

    left outer join tmp_assignments as nameA
        on (I.source, I.filename, I.entry, I.interactoridA) = 
           (nameA.source, nameA.filename, nameA.entry, nameA.interactorid)
        and I.edgetype <> 'C'
    left outer join taxonomy_names as taxnamesA
        on nameA.taxid = taxnamesA.taxid
        and taxnamesA.nameclass = 'scientific name'

    -- Information for interactor B.

    inner join tmp_assignments as nameB
        on (I.source, I.filename, I.entry, I.interactoridB) = 
           (nameB.source, nameB.filename, nameB.entry, nameB.interactorid)
    left outer join taxonomy_names as taxnamesB
        on nameB.taxid = taxnamesB.taxid
        and taxnamesB.nameclass = 'scientific name';

analyze tmp_interactor_experiments;

-- Collect all participant-, interactor- and interaction-related information.

create temporary table tmp_mitab_interactions as
    select I.*,

        -- biologicalRoleA

        case when edgetype = 'C' or bioroleA.refvalues is null or array_length(bioroleA.refvalues, 1) = 0 then '-'
             else array_to_string(bioroleA.refvalues, '|')
        end as biologicalRoleA,

        -- biologicalRoleB

        case when bioroleB.refvalues is null or array_length(bioroleB.refvalues, 1) = 0 then '-'
             else array_to_string(bioroleB.refvalues, '|')
        end as biologicalRoleB,

        -- experimentalRoleA

        case when edgetype = 'C' or exproleA.refvalues is null or array_length(exproleA.refvalues, 1) = 0 then '-'
             else array_to_string(exproleA.refvalues, '|')
        end as experimentalRoleA,

        -- experimentalRoleB

        case when exproleB.refvalues is null or array_length(exproleB.refvalues, 1) = 0 then '-'
             else array_to_string(exproleB.refvalues, '|')
        end as experimentalRoleB

    from tmp_interactor_experiments as I

    -- Information for participant A.

    left outer join tmp_participants as bioroleA
        on (I.source, I.filename, I.entry, I.participantidA) = (bioroleA.source, bioroleA.filename, bioroleA.entry, bioroleA.participantid)
        and bioroleA.property = 'biologicalRole'
        and I.edgetype <> 'C'
    left outer join tmp_participants as exproleA
        on (I.source, I.filename, I.entry, I.participantidA) = (exproleA.source, exproleA.filename, exproleA.entry, exproleA.participantid)
        and exproleA.property = 'experimentalRole'
        and I.edgetype <> 'C'

    -- Information for participant B.

    left outer join tmp_participants as bioroleB
        on (I.source, I.filename, I.entry, I.participantidB) = (bioroleB.source, bioroleB.filename, bioroleB.entry, bioroleB.participantid)
        and bioroleB.property = 'biologicalRole'
    left outer join tmp_participants as exproleB
        on (I.source, I.filename, I.entry, I.participantidB) = (exproleB.source, exproleB.filename, exproleB.entry, exproleB.participantid)
        and exproleB.property = 'experimentalRole';

analyze tmp_mitab_interactions;

-- Combine with ROG-related information to produce MITAB-appropriate records.

create temporary table tmp_mitab_all as
    select
        cast('uidA' as varchar) as uidA,
        cast('uidB' as varchar) as uidB,
        cast('altA' as varchar) as altA,
        cast('altB' as varchar) as altB,
        cast('aliasA' as varchar) as aliasA,
        cast('aliasB' as varchar) as aliasB,
        cast('method' as varchar) as method,
        cast('author' as varchar) as author,
        cast('pmids' as varchar) as pmids,
        cast('taxa' as varchar) as taxA,
        cast('taxb' as varchar) as taxB,
        cast('interactionType' as varchar) as interactionType,
        cast('sourcedb' as varchar) as sourcedb,
        cast('interactionIdentifier' as varchar) as interactionIdentifier,
        cast('confidence' as varchar) as confidence,
        cast('expansion' as varchar) as expansion,
        cast('biological_role_A' as varchar) as biologicalRoleA,
        cast('biological_role_B' as varchar) as biologicalRoleB,
        cast('experimental_role_A' as varchar) as experimentalRoleA,
        cast('experimental_role_B' as varchar) as experimentalRoleB,
        cast('interactor_type_A' as varchar) as interactorTypeA,
        cast('interactor_type_B' as varchar) as interactorTypeB,
        cast('xrefs_A' as varchar) as xrefsA,
        cast('xrefs_B' as varchar) as xrefsB,
        cast('xrefs_Interaction' as varchar) as xrefsInteraction,
        cast('Annotations_A' as varchar) as annotationsA,
        cast('Annotations_B' as varchar) as annotationsB,
        cast('Annotations_Interaction' as varchar) as annotationsInteraction,
        cast('Host_organism_taxid' as varchar) as hostOrganismTaxid,
        cast('parameters_Interaction' as varchar) as parametersInteraction,
        cast('Creation_date' as varchar) as creationDate,
        cast('Update_date' as varchar) as updateDate,
        cast('Checksum_A' as varchar) as checksumA,
        cast('Checksum_B' as varchar) as checksumB,
        cast('Checksum_Interaction' as varchar) as checksumInteraction,
        cast('Negative' as varchar) as negative,
        cast('OriginalReferenceA' as varchar) as originalReferenceA,
        cast('OriginalReferenceB' as varchar) as originalReferenceB,
        cast('FinalReferenceA' as varchar) as finalReferenceA,
        cast('FinalReferenceB' as varchar) as finalReferenceB,
        cast('MappingScoreA' as varchar) as mappingScoreA,
        cast('MappingScoreB' as varchar) as mappingScoreB,
        cast('irogida' as varchar) as irogida,
        cast('irogidb' as varchar) as irogidb,
        cast('irigid' as varchar) as irigid,
        cast('crogida' as varchar) as crogida,
        cast('crogidb' as varchar) as crogidb,
        cast('crigid' as varchar) as crigid,
        cast('icrogida' as varchar) as icrogida,
        cast('icrogidb' as varchar) as icrogidb,
        cast('icrigid' as varchar) as icrigid,
        cast('imex_id' as varchar) as imexid,
        cast('edgetype' as varchar) as edgetype,
        cast('numParticipants' as varchar) as numParticipants
    union all

    select

        -- uidA (identifier, preferably uniprotkb accession, refseq, complex as 'complex:...')

        case when edgetype = 'C' then 'complex:' || I.rigid else prefA.dblabel || ':' || prefA.refvalue end as uidA,

        -- uidB (identifier, preferably uniprotkb accession, refseq)

        prefB.dblabel || ':' || prefB.refvalue as uidB,

        -- altA (alternatives for A, preferably uniprotkb accession, refseq, entrezgene/locuslink identifier, including rogid, irogid)
        -- NOTE: Complexes use the 'rogid:' prefix.

        case when edgetype = 'C' then 'rogid:' || I.rigid
             else array_to_string(
                array_cat(
                    rognameA.names,
                    array['rogid:' || I.uidA]
                    ), '|')
        end as altA,

        -- altB (alternatives for B, preferably uniprotkb accession, refseq, entrezgene/locuslink identifier, including rogid, irogid)

        array_to_string(
            array_cat(
                rognameB.names,
                array['rogid:' || I.uidB]
                ), '|') as altB,

        -- aliasA (aliases for A, preferably uniprotkb identifier/entry, entrezgene/locuslink symbol, including crogid, icrogid)
        -- NOTE: Complexes use the 'crogid:', 'icrogid:' prefixes.
        -- NOTE: Need canonical identifiers.

        case when edgetype = 'C' or aliasA.aliases is null or array_length(aliasA.aliases, 1) = 0 then '-'
             else array_to_string(aliasA.aliases, '|')
        end as aliasA,

        -- aliasB (aliases for B, preferably uniprotkb identifier/entry, entrezgene/locuslink symbol, including crogid, icrogid)
        -- NOTE: Need canonical identifiers.

        case when aliasB.aliases is null or array_length(aliasB.aliases, 1) = 0 then '-'
             else array_to_string(aliasB.aliases, '|')
        end as aliasB,

        -- method (interaction detection method as "MI:code(name)")

        method,

        -- authors (as "name-[year[-number]]")
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as authors,

        -- pmids (as "pubmed:...")

        pmids,

        -- taxA (as "taxid:...")

        taxA,

        -- taxB (as "taxid:...")

        taxB,

        -- interactionType (interaction type as "MI:code(name)")
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as interactionType,

        -- sourcedb (as "MI:code(name)" using "MI:0000(name)" for non-CV sources)

        sourcedb,

        -- interactionIdentifier (includes rigid, irigid, and edgetype as "X", "Y" or "C")

        interactionIdentifier,

        -- confidence
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as confidence,

        -- expansion

        case when edgetype = 'C' then 'bipartite' else 'none' end as expansion,

        -- biologicalRoleA

        biologicalRoleA,

        -- biologicalRoleB

        biologicalRoleB,

        -- experimentalRoleA

        experimentalRoleA,

        -- experimentalRoleB

        experimentalRoleB,

        -- interactorTypeA

        case when edgetype = 'C' then 'MI:0315(protein complex)' else 'MI:0326(protein)' end as interactorTypeA,

        -- interactorTypeB

        cast('MI:0326(protein)' as varchar) as interactorTypeB,

        -- xrefsA (always "-")

        cast('-' as varchar) as xrefsA,

        -- xrefsB (always "-")

        cast('-' as varchar) as xrefsB,

        -- xrefsInteraction (always "-")

        cast('-' as varchar) as xrefsInteraction,

        -- annotationsA (always "-")

        cast('-' as varchar) as annotationsA,

        -- annotationsB (always "-")

        cast('-' as varchar) as annotationsB,

        -- annotationsInteraction (always "-")

        cast('-' as varchar) as annotationsInteraction,

        -- hostOrganismTaxid (as "taxid:...")

        hostOrganismTaxid,

        -- parametersInteraction (always "-")

        cast('-' as varchar) as parametersInteraction,

        -- creationDate (the iRefIndex release date as "YYYY/MM/DD")
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as creationDate,

        -- updateDate (the iRefIndex release date as "YYYY/MM/DD")
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as updateDate,

        -- checksumA (the rogid for interactor A as "rogid:...")
        -- NOTE: The prefix is somewhat inappropriate for complexes.

        'rogid:' || I.uidA as checksumA,

        -- checksumB (the rogid for interactor B as "rogid:...")
        -- NOTE: The prefix is somewhat inappropriate for complexes.

        'rogid:' || I.uidB as checksumB,

        -- checksumInteraction (the rigid for the interaction as "rigid:...")

        'rigid:' || I.rigid as checksumInteraction,

        -- negative (always "false")

        false as negative,

        -- originalReferenceA (original primary or secondary reference for A, the rigid of any complex as 'complex:...')
        -- NOTE: This actually appears as "-" in the iRefIndex 9 MITAB output for complexes.

        originalReferenceA,

        -- originalReferenceB (original primary or secondary reference for B)

        originalReferenceB,

        -- finalReferenceA (the original reference for A, or a corrected/complete/updated/unambiguous reference)
        -- NOTE: This actually appears as "-" in the iRefIndex 9 MITAB output for complexes.

        finalReferenceA,

        -- finalReferenceB (the original reference for B, or a corrected/complete/updated/unambiguous reference)

        finalReferenceB,

        -- mappingScoreA (operation characters describing the original-to-final transformation, "-" for complexes)

        mappingScoreA,

        -- mappingScoreB (operation characters describing the original-to-final transformation)

        mappingScoreB,

        -- irogidA (the integer identifier for the rogid for A)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as irogidA,

        -- irogidB (the integer identifier for the rogid for B)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as irogidB,

        -- irigid (the integer identifier for the rigid for the interaction)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as irigid,

        -- crogidA (the canonical rogid for A, not prefixed)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as crogidA,

        -- crogidB (the canonical rogid for B, not prefixed)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as crogidB,

        -- crigid (the canonical rigid for the interaction, not prefixed)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as crigid,

        -- icrogidA (the integer identifier for the canonical rogid for A)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as icrogidA,

        -- icrogidB (the integer identifier for the canonical rogid for B)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as icrogidB,

        -- icrigid (the integer identifier for the canonical rigid for the interaction)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as icrigid,

        -- imexid (as "imex:..." or "-" if not available)
        -- NOTE: TO BE ADDED.

        cast('-' as varchar) as imexid,

        -- edgetype (as "X", "Y" or "C")

        I.edgetype,

        -- numParticipants (the number of participants)

        I.numParticipants

    from tmp_mitab_interactions as I
    left outer join tmp_identifiers as rognameA
        on I.uidA = rognameA.rogid
        and I.edgetype <> 'C'
    left outer join tmp_preferred as prefA
        on I.uidA = prefA.rogid
        and I.edgetype <> 'C'
    inner join tmp_identifiers as rognameB
        on I.uidB = rognameB.rogid
    inner join tmp_preferred as prefB
        on I.uidB = prefB.rogid
    left outer join tmp_aliases as aliasA
        on I.uidA = aliasA.rogid
        and I.edgetype <> 'C'
    left outer join tmp_aliases as aliasB
        on I.uidB = aliasB.rogid;

\copy tmp_mitab_all to '<directory>/mitab_all'

rollback;