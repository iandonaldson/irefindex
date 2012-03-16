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

-- Consolidate assignment information.

create temporary table tmp_assignments as
    select A.*
    from irefindex_assignments_preferred as P
    inner join irefindex_assignments as A
        on (P.source, P.filename, P.entry, P.interactorid, P.sequencelink, P.dblabel, P.refvalue) =
           (A.source, A.filename, A.entry, A.interactorid, A.sequencelink, A.dblabel, A.refvalue);

analyze tmp_assignments;

-- Collect all interactor- and interaction-related information.

create temporary table tmp_mitab_interactions as
    select I.rigid, I.uidA, I.uidB, I.edgetype, I.numParticipants,

        -- interactionIdentifier (includes rigid, irigid, and edgetype as "X", "Y" or "C")

        case when nameI.dblabel is null then ''
             else nameI.dblabel || ':' || nameI.refvalue || '|'
        end || 'rigid:' || I.rigid || '|edgetype:' || I.edgetype as interactionIdentifier,

        -- sourcedb (as "MI:code(name)" using "MI:0000(name)" for non-CV sources)

        coalesce(sourceI.code, 'MI:0000') || '(' || coalesce(sourceI.name, lower(I.source)) || ')' as sourcedb,

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
             else rogA.taxid || '(' || coalesce(taxnamesA.name, '-') || ')'
        end as taxA,

        -- taxB (as "taxid:...")

        rogB.taxid || '(' || coalesce(taxnamesB.name, '-') || ')' as taxB,

        -- mappingScoreA (operation characters describing the original-to-final transformation, "-" for complexes)

        case when edgetype = 'C' then '-' else scoreA.score end as mappingScoreA,

        -- mappingScoreB (operation characters describing the original-to-final transformation)

        scoreB.score as mappingScoreB

    from tmp_interactions as I
    left outer join xml_xref_interactions as nameI
        on (I.source, I.filename, I.entry, I.interactionid) = (nameI.source, nameI.filename, nameI.entry, nameI.interactionid)
    left outer join psicv_terms as sourceI
        on lower(I.source) = sourceI.name

    -- Information for interactor A.

    left outer join tmp_assignments as nameA
        on (I.source, I.filename, I.entry, I.interactoridA) = 
           (nameA.source, nameA.filename, nameA.entry, nameA.interactorid)
        and I.edgetype <> 'C'
    left outer join irefindex_rogids as rogA
        on (I.source, I.filename, I.entry, I.interactoridA) = (rogA.source, rogA.filename, rogA.entry, rogA.interactorid)
        and I.edgetype <> 'C'
    left outer join taxonomy_names as taxnamesA
        on rogA.taxid = taxnamesA.taxid
        and nameclass = 'scientific name'
    left outer join irefindex_assignment_scores as scoreA
        on (I.source, I.filename, I.entry, I.interactoridA) = (scoreA.source, scoreA.filename, scoreA.entry, scoreA.interactorid)
        and I.edgetype <> 'C'

    -- Information for interactor B.

    inner join tmp_assignments as nameB
        on (I.source, I.filename, I.entry, I.interactoridB) = 
           (nameB.source, nameB.filename, nameB.entry, nameB.interactorid)
    inner join irefindex_rogids as rogB
        on (I.source, I.filename, I.entry, I.interactoridB) = (rogB.source, rogB.filename, rogB.entry, rogB.interactorid)
    left outer join taxonomy_names as taxnamesB
        on rogB.taxid = taxnamesB.taxid
        and nameclass = 'scientific name'
    inner join irefindex_assignment_scores as scoreB
        on (I.source, I.filename, I.entry, I.interactoridB) = (scoreB.source, scoreB.filename, scoreB.entry, scoreB.interactorid);

-- Combine with ROG-related information to produce MITAB-appropriate records.

create temporary table tmp_mitab_all as
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

        case when edgetype = 'C' then ''
             else array_to_string(aliasA.aliases, '|')
        end as aliasA,

        -- aliasB (aliases for B, preferably uniprotkb identifier/entry, entrezgene/locuslink symbol, including crogid, icrogid)
        -- NOTE: Need canonical identifiers.

        array_to_string(aliasB.aliases, '|') as aliasB,

        -- method (interaction detection method as "MI:code(name)")
        -- authors (as "name-[year[-number]]")
        -- pmids (as "pubmed:...")
        -- taxA (as "taxid:...")

        taxA,

        -- taxB (as "taxid:...")

        taxB,

        -- interactionType (interaction type as "MI:code(name)")
        -- sourcedb (as "MI:code(name)" using "MI:0000(name)" for non-CV sources)

        sourcedb,

        -- interactionIdentifier (includes rigid, irigid, and edgetype as "X", "Y" or "C")

        interactionIdentifier,

        -- confidence
        -- expansion

        case when edgetype = 'C' then 'bipartite' else 'none' end as expansion,

        -- biologicalRoleA
        -- biologicalRoleB
        -- experimentalRoleA
        -- experimentalRoleB
        -- interactorTypeA

        case when edgetype = 'C' then 'MI:0315(protein complex)' else 'MI:0326(protein)' end as interactorTypeA,

        -- interactorTypeB

        'MI:0326(protein)' as interactorTypeB,

        -- xrefsA (always "-")

        '-' as xrefsA,

        -- xrefsB (always "-")

        '-' as xrefsB,

        -- xrefsInteraction (always "-")

        '-' as xrefsInteraction,

        -- annotationsA (always "-")

        '-' as annotationsA,

        -- annotationsB (always "-")

        '-' as annotationsB,

        -- annotationsInteraction (always "-")

        '-' as annotationsInteraction,

        -- hostOrganismTaxid (as "taxid:...")
        -- parametersInteraction (always "-")

        '-' as parametersInteraction,

        -- creationDate (the iRefIndex release date as "YYYY/MM/DD")
        -- updateDate (the iRefIndex release date as "YYYY/MM/DD")
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
        -- irogidB (the integer identifier for the rogid for B)
        -- irigid (the integer identifier for the rigid for the interaction)
        -- crogidA (the canonical rogid for A, not prefixed)
        -- crogidB (the canonical rogid for B, not prefixed)
        -- crigid (the canonical rigid for the interaction, not prefixed)
        -- icrogidA (the integer identifier for the canonical rogid for A)
        -- icrogidB (the integer identifier for the canonical rogid for B)
        -- icrigid (the integer identifier for the canonical rigid for the interaction)
        -- imexid (as "imex:..." or "-" if not available)
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
