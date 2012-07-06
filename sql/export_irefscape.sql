begin;

-- To make RIG attributes in a format enjoyed by Cytoscape, various data types
-- must be combined in a way not unlike the MITAB data preparation.

-- Create an arbitrary interaction identifier for each source interaction.

create temporary sequence tmp_sourceid;

create temporary table tmp_arbitrary as
    select nextval('tmp_sourceid') as sourceid, source, filename, entry, interactionid
    from (
        select distinct source, filename, entry, interactionid
        from irefindex_interactions
        ) as X;

create index tmp_arbitrary_index on tmp_arbitrary(source, filename, entry, interactionid);
analyze tmp_arbitrary;

-- Get interaction names, choosing the 'fullName' in preference to the 'shortLabel'.

create temporary table tmp_interaction_names as
    select source, filename, entry, interactionid, name[2] as name
    from (
        select source, filename, entry, interactionid, min(array[nametype, name]) as name
        from xml_names_interaction_names
        group by source, filename, entry, interactionid
        ) as X;

analyze tmp_interaction_names;

-- Get experiment method names, choosing the 'shortLabel' in preference to the 'fullName'.

create temporary table tmp_experiment_names as
    select source, filename, entry, experimentid, property, name[2] as name
    from (
        select source, filename, entry, experimentid, property, max(array[nametype, name]) as name
        from xml_names_experiment_methods
        group by source, filename, entry, experimentid, property
        ) as X;

analyze tmp_experiment_names;

-- Various gene-related lists of names, synonyms and symbols.
-- This reproduces various operations in the previous iRefScape data preparation.

create temporary table tmp_uniprot_rogids as
    select sequence || taxid as rogid, uniprotid
    from uniprot_proteins
    where taxid is not null;

analyze tmp_uniprot_rogids;

create temporary table tmp_gene_rogids as
    select rogid, symbol
    from irefindex_gene2rog as R
    inner join gene_info as G
        on R.geneid = G.geneid;

analyze tmp_gene_rogids;

create temporary table tmp_gene_synonym_rogids as
    select distinct rogid, "synonym"
    from irefindex_gene2rog as G
    inner join gene_synonyms as S
        on G.geneid = S.geneid;

analyze tmp_gene_synonym_rogids;

-- NOTE: Using "union" instead of "distinct ... union all" seems to require
-- NOTE: less memory.

create temporary table tmp_all_gene_synonym_rogids as
    select rogid, "synonym"
    from (
        select rogid, "synonym"
        from tmp_gene_synonym_rogids
        union
        select rogid, symbol as "synonym"
        from tmp_gene_rogids
        union
        select rogid, uniprotid as "synonym"
        from tmp_uniprot_rogids
        ) as X;

analyze tmp_all_gene_synonym_rogids;



-- Obtain participant role information.
-- The participant method output is built here since making a string from an
-- array of nulls results in an empty string that can be easily detected later.

create temporary table tmp_participants as
    select I.source, I.filename, I.entry, I.interactionid, I.rigid,
        count(roleP.refvalue) as baits,
        array_accum(rog) as rogs,
        array_to_string(array_accum(methodP.refvalue), '|') as partmethods,
        array_to_string(array_accum(methodnameP.name), '|') as partmethodnames

    from irefindex_interactions as I

    -- Participant roles.

    left outer join xml_xref_participants as roleP
        on (I.source, I.filename, I.entry, I.participantid) =
           (roleP.source, roleP.filename, roleP.entry, roleP.participantid)
        and roleP.property = 'experimentalRole'
        and roleP.refvalue = 'MI:0496' -- bait

    -- Integer identifiers.

    inner join irefindex_rog2rogid as irog
        on I.rogid = irog.rogid

    -- Participant identification methods.

    left outer join xml_xref_participants as methodP
        on (I.source, I.filename, I.entry, I.participantid) =
           (methodP.source, methodP.filename, methodP.entry, methodP.participantid)
        and methodP.property = 'participantIdentificationMethod'

    -- Participant method names.

    left outer join psicv_terms as methodnameP
        on methodP.refvalue = methodnameP.code
        and methodnameP.nametype = 'preferred'

    -- Accumulate ROG, participant and bait details.

    group by I.source, I.filename, I.entry, I.interactionid, I.rigid;

analyze tmp_participants;

-- Add observed interaction-related information.

create temporary table tmp_interactions as
    select I.source, I.filename, I.entry, I.interactionid, I.rigid,
        baits, rogs, partmethods, partmethodnames,
        intI.refvalue,
        typeI.refvalue as interactiontype, typenameI.name as interactiontypename,
        nameI.name as interactionname

    from tmp_participants as I

    -- Interaction identifiers.

    left outer join xml_xref_interactions as intI
        on (I.source, I.filename, I.entry, I.interactionid) =
           (intI.source, intI.filename, intI.entry, intI.interactionid)

    -- Interaction types.

    left outer join xml_xref_interaction_types as typeI
        on (I.source, I.filename, I.entry, I.interactionid) =
           (typeI.source, typeI.filename, typeI.entry, typeI.interactionid)

    -- Interaction type names.

    left outer join psicv_terms as typenameI
        on typeI.refvalue = typenameI.code
        and typenameI.nametype = 'preferred'

    -- Interaction names.

    left outer join tmp_interaction_names as nameI
        on (I.source, I.filename, I.entry, I.interactionid) =
           (nameI.source, nameI.filename, nameI.entry, nameI.interactionid);

analyze tmp_interactions;

-- Combine interaction information together with score data.
-- Note that we build the eventual string for the output here because we need to
-- combine the sourceid with the score details when formatting the output.

create temporary table tmp_scored_interactions as
    select I.source, I.filename, I.entry, I.interactionid, I.rigid,
        baits, rogs, partmethods, partmethodnames,
        sourceid, refvalue, interactiontype, interactiontypename, interactionname,
        array_to_string(array_accum('||i.score_' || scoretype || '=>' || sourceid || '>>' || score), '') as scores

    -- Interaction identifiers.

    from tmp_interactions as I

    -- Get arbitrary interaction identifiers.

    inner join tmp_arbitrary as A
        on (I.source, I.filename, I.entry, I.interactionid) =
           (A.source, A.filename, A.entry, A.interactionid)

    -- Confidence scores.

    left outer join irefindex_confidence as confI
        on I.rigid = confI.rigid

    group by I.source, I.filename, I.entry, I.interactionid, I.rigid,
        baits, rogs, partmethods, partmethodnames,
        sourceid, refvalue, interactiontype, interactiontypename, interactionname;

analyze tmp_scored_interactions;

-- Collect experiment-related information.

create temporary table tmp_experiments as
    select E.source, E.filename, E.entry, E.interactionid, E.experimentid,
        taxidE.taxid, pubmedE.refvalue as pmid, methodE.refvalue as expmethod,
        coalesce(methodnameE.name, othermethodnameE.name) as expmethodname,
        authorE.name as author

    from xml_experiments as E

    -- Host organisms.

    left outer join xml_xref_experiment_organisms as taxidE
        on (E.source, E.filename, E.entry, E.experimentid) =
           (taxidE.source, taxidE.filename, taxidE.entry, taxidE.experimentid)
    left outer join taxonomy_names as taxnamesE
        on taxidE.taxid = taxnamesE.taxid
        and taxnamesE.nameclass = 'scientific name'

    -- PubMed identifiers.

    left outer join xml_xref_experiment_pubmed as pubmedE
        on (E.source, E.filename, E.entry, E.experimentid) =
           (pubmedE.source, pubmedE.filename, pubmedE.entry, pubmedE.experimentid)

    -- Interaction detection methods.

    left outer join xml_xref_experiment_methods as methodE
        on (E.source, E.filename, E.entry, E.experimentid) =
           (methodE.source, methodE.filename, methodE.entry, methodE.experimentid)

    -- Interaction method names.

    left outer join psicv_terms as methodnameE
        on methodE.refvalue = methodnameE.code
        and methodnameE.nametype = 'preferred'

    -- Authors.

    left outer join xml_names_experiment_authors as authorE
        on (E.source, E.filename, E.entry, E.experimentid) =
           (authorE.source, authorE.filename, authorE.entry, authorE.experimentid)

    -- Methods as names.

    left outer join tmp_experiment_names as othermethodnameE
        on (E.source, E.filename, E.entry, E.experimentid) =
           (othermethodnameE.source, othermethodnameE.filename, othermethodnameE.entry, othermethodnameE.experimentid)
        and othermethodnameE.property = 'interactionDetectionMethod';

analyze tmp_experiments;



-- At last, we can now combine the scored interaction details with experiment
-- information and integer identifiers to produce the RIG attributes.

create temporary table tmp_rigid_attributes as
    select I.rigid

        -- Integer identifiers for ROGs, RIGs.

        || '||i.rog=>' || array_to_string(rogs, '|')
        || '||i.rig=>' || sourceid || '>>' || irig.rig
        || '||i.canonical_rig=>' || sourceid || '>>' || icrig.rig

        -- Interaction type information.
        -- NOTE: This does not replicate the type name used in previous iRefIndex
        -- NOTE: releases since a fairly complicated way of constructing descriptions
        -- NOTE: of interactions appears to have been used.

        || case when interactiontype is not null or interactionname is not null then
                     '||i.type_name=>' || sourceid || '>>' || coalesce(interactiontypename, interactionname)
                else ''
           end
        || case when interactiontype is not null then
                     '||i.type_cv=>' || sourceid || '>>' || interactiontype
                else ''
           end

        -- Article information.

        || case when pmid is not null then
                     '||i.PMID=>' || sourceid || '>>' || pmid
                else ''
           end

        -- Host organism information.

        || case when taxid is not null then
                     '||i.host_taxid=>' || sourceid || '>>' || taxid
                else ''
           end

        -- Data source and interaction identifier details.

        || '||i.src_intxn_db=>' || sourceid || '>>' || lower(I.source)
        || '||i.src_intxn_id=>' || sourceid || '>>' || coalesce(I.refvalue, 'NA')

        -- Interaction detection and participant identification methods.

        || case when expmethodname is not null then
                     '||i.method_name=>' || sourceid || '>>' || expmethodname
                else ''
           end
        || case when expmethod is not null then
                     '||i.method_cv=>' || sourceid || '>>' || expmethod
                else ''
           end
        || case when partmethodnames <> '' then
                     '||i.participant_identification=>' || sourceid || '>>' || partmethodnames
                else ''
           end
        || case when partmethods <> '' then
                     '||i.participant_identification_cv=>' || sourceid || '>>' || partmethods
                else ''
           end

        -- Author information.

        || case when author is not null then
                     '||i.experiment=>' || sourceid || '>>' || author
                else ''
           end

        -- Number of bait interactors (non-distinct).

        || case when baits <> 0 then
                     '||i.bait=>' || sourceid || '>>' || baits
                else ''
           end

        -- NOTE: Need a description of these fields.

        || '||i.target_protein=>' || sourceid || '>>-1'
        || '||i.source_protein=>' || sourceid || '>>-1'

        -- Confidence scores.

        || scores

    from tmp_scored_interactions as I
    inner join tmp_experiments as E
        on (I.source, I.filename, I.entry, I.interactionid) =
           (E.source, E.filename, E.entry, E.interactionid)

    -- Canonical interactions.

    inner join irefindex_rigids_canonical as C
        on I.rigid = C.rigid

    -- Integer identifiers.

    inner join irefindex_rig2rigid as irig
        on I.rigid = irig.rigid
    inner join irefindex_rig2rigid as icrig
        on C.crigid = icrig.rigid;

\copy tmp_rigid_attributes to '<directory>/rigAtributes.irfi'

-- Specific ROG integer identifiers mapped to canonical ROG integer identifiers.

create temporary table tmp_rog2canonicalrog as
    select SI.rog || '|+|' || CI.rog
    from irefindex_rogids_canonical as R
    inner join irefindex_rog2rogid as SI
        on R.rogid = SI.rogid
    inner join irefindex_rog2rogid as CI
        on R.crogid = CI.rogid;

\copy tmp_rog2canonicalrog to '<directory>/ROG2CANONICALROG.irfm'

-- Canonical ROG integer identifiers mapped to specific ROG integer identifiers.

create temporary table tmp_canonicalrog2rogs as
    select CI.rog || '|+|' || array_to_string(array_accum(distinct SI.rog), '|')
    from irefindex_rogids_canonical as R
    inner join irefindex_rog2rogid as SI
        on R.rogid = SI.rogid
    inner join irefindex_rog2rogid as CI
        on R.crogid = CI.rogid
    group by CI.rog;

\copy tmp_canonicalrog2rogs to '<directory>/CANONICALROG2ROG.irfm'

-- Specific and canonical ROG integer identifiers with taxonomy identifiers.

create temporary table tmp_canonical_rogs as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.canonical_rog=>|' || CI.rog
    from irefindex_rogids_canonical as R
    inner join irefindex_rog2rogid as SI
        on R.rogid = SI.rogid
    inner join irefindex_rog2rogid as CI
        on R.crogid = CI.rogid;

\copy tmp_canonical_rogs to '<directory>/_EXT__ROG__EXPORT_canonical_rog.irft'

-- ROG integer identifiers and accessions with taxonomy identifiers.

create temporary table tmp_rog_accessions as
    select SI.rog || '|+|i.taxid=>' || S.reftaxid || '|+|i.xref=>|' || array_to_string(array_accum(dblabel || ':' || refvalue), '|') || '|'
    from xml_xref_sequences as S
    inner join irefindex_rog2rogid as SI
        on S.refsequence || S.reftaxid = SI.rogid
    group by SI.rog, S.reftaxid;

\copy tmp_rog_accessions to '<directory>/_COL__ROG_xref.irft'

-- ROG identifiers with taxonomy identifiers.

create temporary table tmp_rogids as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.rogid=>|' || SI.rogid || '|'
    from irefindex_rog2rogid as SI;

\copy tmp_rogids to '<directory>/_ONE__EXT__ROG_ROGID.irft'

-- ROG integer identifiers with taxonomy identifiers and a selection of names.
-- NOTE: The names used do not necessarily replicate those found in previous
-- NOTE: iRefIndex releases.

create temporary table tmp_rog_fullnames as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.interactor_description=>|'
        || array_to_string(array_accum(upper(replace("synonym", '|', '_'))), '|') || '|'
    from irefindex_rog2rogid as SI
    inner join tmp_all_gene_synonym_rogids as S
        on SI.rogid = S.rogid
    group by SI.rog, SI.rogid;

analyze tmp_rog_fullnames;

\copy tmp_rog_fullnames to '<directory>/_ROG_fullname.irft'

-- ROG integer identifiers mapped to display names.
-- Names can be one of the following: UniProt identifiers, gene symbols, gene
-- synonyms, locustags, UniProt accessions, other identifiers (GenBank, FlyBase,
-- RefSeq), or ROG identifier.

-- NOTE: Need to fully support the above list of identifier types.

create temporary table tmp_display_names as
    select rog || '|+|i.displayLabel=>|' || upper(name)
    from (
        select SI.rog, coalesce(
            U.uniprotid,
            G.symbol,
            array_to_string(array_accum(upper(replace("synonym", '|', '_'))), '|'),
            I.dblabel || ':' || replace(I.refvalue, '|', '_')
            ) as name
        from irefindex_rog2rogid as SI
        left outer join tmp_uniprot_rogids as U
            on SI.rogid = U.rogid
        left outer join tmp_gene_rogids as G
            on SI.rogid = G.rogid
        left outer join tmp_all_gene_synonym_rogids as S
            on SI.rogid = S.rogid
        inner join irefindex_all_rogid_identifiers as I
            on SI.rogid = I.rogid
        group by SI.rog, U.uniprotid, G.symbol, I.dblabel, I.refvalue
        ) as X
    group by rog, name;

\copy tmp_display_names to '<directory>/_ROG_displaylabel.irft'

-- ROG integer identifiers mapped to UniProt accessions with taxonomy details.

create temporary table tmp_uniprot_accessions as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.UniProt_Ac=>|' || refvalue
    from irefindex_rog2rogid as SI
    inner join irefindex_rogid_identifiers as I
        on SI.rogid = I.rogid
        and dblabel = 'uniprotkb'
    group by SI.rog, SI.rogid, refvalue;

\copy tmp_uniprot_accessions to '<directory>/_ROG__EXT__EXPORT_UniProt_Ac.irft'

-- ROG integer identifiers mapped to UniProt identifiers with taxonomy details.

create temporary table tmp_uniprot_names as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.UniProt_ID=>|' || uniprotid
    from irefindex_rog2rogid as SI
    inner join tmp_uniprot_rogids as U
        on SI.rogid = U.rogid
    group by SI.rog, SI.rogid, uniprotid;

\copy tmp_uniprot_names to '<directory>/_ROG__EXT__EXPORT_UniProt_ID.irft'

-- ROG integer identifiers mapped to gene identifiers with taxonomy details.

create temporary table tmp_geneids as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.geneID=>|' || geneid || '|'
    from irefindex_rog2rogid as SI
    inner join irefindex_gene2rog as G
        on SI.rogid = G.rogid
    group by SI.rog, SI.rogid, geneid;

\copy tmp_geneids to '<directory>/_EXT__EXPORT__ROG_geneID.irft'

-- ROG integer identifiers mapped to molecular weights with taxonomy details.

create temporary table tmp_mw as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.mw=>|' || mw || '|'
    from irefindex_rog2rogid as SI
    inner join irefindex_rogid_identifiers as I
        on SI.rogid = I.rogid
    inner join uniprot_proteins as U
        on I.refvalue = U.accession
        and I.dblabel = 'uniprotkb'
    group by SI.rog, SI.rogid, mw;

\copy tmp_mw to '<directory>/_EXT__RANGE__ROG_mass.irft'

-- ROG integer identifiers mapped to IPI identifiers with taxonomy details.

create temporary table tmp_ipi as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.ipi=>|' || refvalue
    from irefindex_rog2rogid as SI
    inner join irefindex_rogid_identifiers as I
        on SI.rogid = I.rogid
        and dblabel = 'ipi'
    group by SI.rog, SI.rogid, refvalue;

\copy tmp_ipi to '<directory>/_ROG__EXPORT_ipi.irft'

-- ROG integer identifiers mapped to RIG identifiers and other ROGs in an interaction.

create temporary table tmp_rog2rigid as
    select I.rog || '|+|' || R.rigid || '|+|' || array_to_string(array_accum(distinct I2.rog), '+')
    from irefindex_distinct_interactions as R
    inner join irefindex_distinct_interactions as R2
        on R.rigid = R2.rigid

    -- The principal ROG.

    inner join irefindex_rog2rogid as I
        on R.rogid = I.rogid

    -- Other ROGs.

    inner join irefindex_rog2rogid as I2
        on R2.rogid = I2.rogid
    group by R.rigid, I.rog;

\copy tmp_rog2rigid to '<directory>/rog2rig.irfm'

-- ROG integer identifiers mapped to GO term names with taxonomy details.

create temporary table tmp_go_functions as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.function=>|' || array_to_string(array_accum(distinct term), '|')
    from irefindex_rog2rogid as SI
    inner join irefindex_gene2rog as G
        on SI.rogid = G.rogid
    inner join gene2go as GG
        on G.geneid = GG.geneid
        and GG.category = 'Function'
    group by SI.rog, SI.rogid;

\copy tmp_go_functions to '<directory>/_EXT__ROG_Function.irft'

create temporary table tmp_go_components as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.function=>|' || array_to_string(array_accum(distinct term), '|')
    from irefindex_rog2rogid as SI
    inner join irefindex_gene2rog as G
        on SI.rogid = G.rogid
    inner join gene2go as GG
        on G.geneid = GG.geneid
        and GG.category = 'Component'
    group by SI.rog, SI.rogid;

\copy tmp_go_functions to '<directory>/_EXT__ROG_Component.irft'

create temporary table tmp_go_processes as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.function=>|' || array_to_string(array_accum(distinct term), '|')
    from irefindex_rog2rogid as SI
    inner join irefindex_gene2rog as G
        on SI.rogid = G.rogid
    inner join gene2go as GG
        on G.geneid = GG.geneid
        and GG.category = 'Process'
    group by SI.rog, SI.rogid;

\copy tmp_go_functions to '<directory>/_EXT__ROG_Process.irft'

-- ROG integer identifiers mapped to chromosome information with taxonomy details.

create temporary table tmp_chromosomes as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.chromosome=>|' || chromosome || '|'
    from irefindex_rog2rogid as SI
    inner join irefindex_gene2rog as G
        on SI.rogid = G.rogid
    inner join gene_info as GI
        on G.geneid = GI.geneid
    group by SI.rog, SI.rogid, chromosome;

\copy tmp_chromosomes to '<directory>/_ROG_chromosome.irft'

-- ROG integer identifiers mapped to maplocation information with taxonomy details.

create temporary table tmp_maplocations as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.maplocation=>|' || array_to_string(array_accum(maplocation), '|') || '|'
    from irefindex_rog2rogid as SI
    inner join irefindex_gene2rog as G
        on SI.rogid = G.rogid
    inner join gene_maplocations as GM
        on G.geneid = GM.geneid
    group by SI.rog, SI.rogid;

\copy tmp_maplocations to '<directory>/_ROG_maplocation.irft'

-- PubMed identifiers for RIG identifiers.

create temporary table tmp_pmids as
    select '|' || P.refvalue || '|+|' || rigid
    from irefindex_rigids as I
    inner join xml_experiments as E
        on (I.source, I.filename, I.entry, I.interactionid) =
           (E.source, E.filename, E.entry, E.interactionid)
    inner join xml_xref_experiment_pubmed as P
        on (E.source, E.filename, E.entry, E.experimentid) =
           (P.source, P.filename, P.entry, P.experimentid)
    group by P.refvalue, rigid;

\copy tmp_pmids to '<directory>/_EXT__RIG_PMID.irft'

-- ROG integer identifiers mapped to interactor short labels with taxonomy details.

create temporary table tmp_shortlabels as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.interactor_shortlbl=>|'
        || array_to_string(array_accum(distinct upper(name)), '|') || '|'
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join xml_names_interactor_names as N
        on (R.source, R.filename, R.entry, R.interactorid) =
           (N.source, N.filename, N.entry, N.interactorid)
        and nametype = 'shortLabel'
    group by SI.rog, SI.rogid;

\copy tmp_shortlabels to '<directory>/_ROG_ShortLabel.irft'

-- ROG integer identifiers mapped to interactor synonyms with taxonomy details.
-- NOTE: Adopting the previous spelling of the attribute name.

create temporary table tmp_synonyms as
    select SI.rog
        || '|+|i.taxid=>' || substring(SI.rogid from 28)
        || '|+|i.interactor_synonims=>|'
        || array_to_string(array_accum(upper(replace("synonym", '|', '_'))), '|')
        || '|'
    from irefindex_rog2rogid as SI
    inner join tmp_all_gene_synonym_rogids as S
        on SI.rogid = S.rogid
    group by SI.rog, SI.rogid
    having count("synonym") > 0;

\copy tmp_synonyms to '<directory>/_ROG_synonyms.irft'

-- Interaction references mapped to RIG identifiers.

create temporary table tmp_interaction2rig as
    select refvalue, rigid
    from xml_xref_interactions as I
    inner join irefindex_rigids as R
        on (I.source, I.filename, I.entry, I.interactionid) = 
           (R.source, R.filename, R.entry, R.interactionid);

\copy tmp_interaction2rig to '<directory>/_EXT__RIG_src_intxn_id.irft'



-- A pairwise mapping of ROG integer identifiers for each interaction.
-- This is processed by the irdata_convert_graph.py tool.

create temporary table tmp_graph as
    select I.rog as rogA, I2.rog as rogB
    from irefindex_distinct_interactions as R
    inner join irefindex_distinct_interactions as R2
        on R.rigid = R2.rigid

    -- The principal ROG.

    inner join irefindex_rog2rogid as I
        on R.rogid = I.rogid

    -- Other ROGs.

    inner join irefindex_rog2rogid as I2
        on R2.rogid = I2.rogid

    where I.rog < I2.rog
    group by I.rog, I2.rog;

-- NOTE: Perhaps this isn't needed because the graph is typically processed by
-- NOTE: some Java tools that reproduce the ROG graph-related queries elsewhere
-- NOTE: in this file.

\copy tmp_graph to '<directory>/graph'

-- ROG integer identifiers and their neighbours in the graph.

create temporary table tmp_graph_neighbours as
    select rogA || '|+|' || array_to_string(array_accum(rogB), '+')
    from tmp_graph
    group by rogA;

\copy tmp_graph_neighbours to '<directory>/rog2full_neighbourhood.irfm'

-- ROG integer identifiers mapped to their degree in the graph.

create temporary table tmp_graph_degree_index as
    select rogA || '|+|i.taxid=>-10|+|i.overall_degree=>|' || count(rogB) || '|'
    from tmp_graph
    group by rogA;

\copy tmp_graph_degree_index to '<directory>/_EXT__ROG_overall_degree.irft'

rollback;
