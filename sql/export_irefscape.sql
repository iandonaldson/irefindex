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

create temporary table tmp_gene_symbol_rogids as
    select rogid, symbol
    from irefindex_gene2rog as R
    inner join gene_info as G
        on R.geneid = G.geneid;

analyze tmp_gene_symbol_rogids;

create temporary table tmp_gene_synonym_rogids as
    select distinct rogid, "synonym"
    from irefindex_gene2rog as G
    inner join gene_synonyms as S
        on G.geneid = S.geneid;

analyze tmp_gene_synonym_rogids;

-- NOTE: Using "union" instead of "distinct ... union all" seems to require
-- NOTE: less memory.

create temporary table tmp_all_gene_synonym_rogids as
    select rogid, replace(replace(replace("synonym", '|', '_'), '/', '_'), E'\\', '_') as "synonym"
    from (
        select rogid, "synonym"
        from tmp_gene_synonym_rogids
        union
        select rogid, symbol as "synonym"
        from tmp_gene_symbol_rogids
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
        rogs,
        array_to_string(array_accum(distinct methodP.refvalue), '|') as partmethods,
        array_to_string(array_accum(distinct methodnameP.name), '|') as partmethodnames
    from (

        -- Get ordered ROG integer identifiers for specific interactions.

        select source, filename, entry, interactionid, rigid, array_accum(rog) as rogs
        from (

            select I.source, I.filename, I.entry, I.interactionid, I.rigid, rog

            from irefindex_interactions as I

            -- Integer identifiers.

            inner join irefindex_rog2rogid as irog
                on I.rogid = irog.rogid

            -- Accumulate ROG, participant and bait details.

            order by I.source, I.filename, I.entry, I.interactionid, I.rigid, rog

            ) as X

        group by source, filename, entry, interactionid, rigid

        ) as Y

    inner join irefindex_interactions as I
        on (Y.source, Y.filename, Y.entry, Y.interactionid) =
           (I.source, I.filename, I.entry, I.interactionid)

    -- Participant roles.

    left outer join xml_xref_participants as roleP
        on (I.source, I.filename, I.entry, I.participantid) =
           (roleP.source, roleP.filename, roleP.entry, roleP.participantid)
        and roleP.property = 'experimentalRole'
        and roleP.refvalue = 'MI:0496' -- bait

    -- Participant identification methods.

    left outer join xml_xref_participants as methodP
        on (I.source, I.filename, I.entry, I.participantid) =
           (methodP.source, methodP.filename, methodP.entry, methodP.participantid)
        and methodP.property = 'participantIdentificationMethod'

    -- Participant method names.

    left outer join psicv_terms as methodnameP
        on methodP.refvalue = methodnameP.code
        and methodnameP.nametype = 'preferred'

    group by I.source, I.filename, I.entry, I.interactionid, I.rigid, rogs;

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

create temporary table tmp_scored_interactions as
    select rigid, array_to_string(array_accum(case when scores <> '' then 'i.score_' || scoretype || '=>' || scores else '' end), '||') as scores
    from (

        select I.rigid, scoretype, array_to_string(array_accum(sourceid || '>>' || score), '|') as scores

        -- Interaction identifiers.

        from tmp_interactions as I

        -- Get arbitrary interaction identifiers.

        inner join tmp_arbitrary as A
            on (I.source, I.filename, I.entry, I.interactionid) =
               (A.source, A.filename, A.entry, A.interactionid)

        -- Confidence scores.

        left outer join irefindex_confidence as confI
            on I.rigid = confI.rigid

        group by I.rigid, scoretype

        ) as X

    group by rigid;

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
-- Here, we create records unlike previous iRefIndex releases since this file
-- itself is only used to create others with the given format.

create temporary table tmp_rigid_attributes as
    select rigid

        ||                                      '|++|i.src_intxn_id=>'                  || srcintxnids
        ||                                      '|+|i.rog=>'                            || rogs
        ||                                      '||i.rig=>'                             || rig
        ||                                      '||i.canonical_rig=>'                   || canonicalrigs
        || case when typenames <> '' then       '||i.type_name=>'                       || typenames
           else '' end
        || case when typecvs <> '' then         '||i.type_cv=>'                         || typecvs
           else '' end
        || case when pmids <> '' then           '||i.PMID=>'                            || pmids
           else '' end
        || case when taxids <> '' then          '||i.host_taxid=>'                      || taxids
           else '' end
        ||                                      '||i.src_intxn_db=>'                    || srcintxndbs
        || case when expmethodnames <> '' then  '||i.method_name=>'                     || expmethodnames
           else '' end
        || case when expmethods <> '' then      '||i.method_cv=>'                       || expmethods
           else '' end
        || case when partmethodnames <> '' then '||i.participant_identification=>'      || partmethodnames
           else '' end
        || case when partmethods <> '' then     '||i.participant_identification_cv=>'   || partmethods
           else '' end
        || case when authors <> '' then         '||i.experiment=>'                      || authors
           else '' end
        || case when baits <> '' then           '||i.bait=>'                            || baits
           else '' end

        -- NOTE: Need a description of these fields.

        ||                                      '||i.target_protein=>'                  || targetproteins
        ||                                      '||i.source_protein=>'                  || sourceproteins

        -- Confidence scores.

        || case when scores <> '' then          '||'                                    || scores
           else '' end

        -- End of record.

        || '||'

    from (

        select rigid,
            array_to_string(array_accum(distinct srcintxnid), '|') as srcintxnids,
            array_to_string(array_accum(distinct rogs), '|') as rogs,
            rig,
            array_to_string(array_accum(distinct canonicalrig), '|') as canonicalrigs,
            array_to_string(array_accum(distinct typename), '|') as typenames,
            array_to_string(array_accum(distinct typecv), '|') as typecvs,
            array_to_string(array_accum(distinct pmid), '|') as pmids,
            array_to_string(array_accum(distinct taxid), '|') as taxids,
            array_to_string(array_accum(distinct srcintxndb), '|') as srcintxndbs,
            array_to_string(array_accum(distinct expmethodname), '|') as expmethodnames,
            array_to_string(array_accum(distinct expmethod), '|') as expmethods,
            array_to_string(array_accum(distinct partmethodnames), '|') as partmethodnames,
            array_to_string(array_accum(distinct partmethods), '|') as partmethods,
            array_to_string(array_accum(distinct author), '|') as authors,
            array_to_string(array_accum(distinct baits), '|') as baits,
            array_to_string(array_accum(distinct targetprotein), '|') as targetproteins,
            array_to_string(array_accum(distinct sourceprotein), '|') as sourceproteins,
            scores

        from (

            -- Get details for source interactions.

            select I.rigid,
                sourceid || '>>' || coalesce(I.refvalue, 'NA') as srcintxnid,
                sourceid || '>>' || lower(I.source) as srcintxndb,

                -- Integer identifiers for ROGs, RIGs.

                array_to_string(rogs, '|') as rogs,
                irig.rig as rig,
                sourceid || '>>' || irig.rig as outputrig,
                sourceid || '>>' || icrig.rig as canonicalrig,

                -- Interaction type information.

                -- NOTE: This does not replicate the type name used in previous iRefIndex
                -- NOTE: releases since a fairly complicated way of constructing descriptions
                -- NOTE: of interactions appears to have been used.

                case when interactiontype is not null or interactionname is not null then
                          sourceid || '>>' || coalesce(interactiontypename, interactionname)
                     else ''
                end as typename,
                case when interactiontype is not null then
                          sourceid || '>>' || interactiontype
                     else ''
                end as typecv,

                -- Article information.

                case when pmid is not null then sourceid || '>>' || pmid else '' end as pmid,

                -- Host organism information.

                case when taxid is not null then sourceid || '>>' || taxid else '' end as taxid,

                -- Interaction detection and participant identification methods.

                case when expmethodname is not null then sourceid || '>>' || expmethodname else '' end as expmethodname,
                case when expmethod is not null then sourceid || '>>' || expmethod else '' end as expmethod,
                case when partmethodnames <> '' then sourceid || '>>' || partmethodnames else '' end as partmethodnames,
                case when partmethods <> '' then sourceid || '>>' || partmethods else '' end as partmethods,

                -- Author information.

                case when author is not null then sourceid || '>>' || author else '' end as author,

                -- Number of bait interactors (non-distinct).

                case when baits <> 0 then sourceid || '>>' || baits else '' end as baits,

                -- Score information for general interactions is already available here.

                scores,

                -- NOTE: Fields set to constant values.

                sourceid || '>>-1' as targetprotein,
                sourceid || '>>-1' as sourceprotein

            from tmp_interactions as I

            -- Get arbitrary interaction identifiers.

            inner join tmp_arbitrary as A
                on (I.source, I.filename, I.entry, I.interactionid) =
                   (A.source, A.filename, A.entry, A.interactionid)

            -- RIG-oriented scores.

            inner join tmp_scored_interactions as SI
                on I.rigid = SI.rigid

            -- Experiment details for specific interactions.

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
                on C.crigid = icrig.rigid

            ) as X

        group by rigid, rig, scores

        ) as Y;

\copy tmp_rigid_attributes to '<directory>/rigAttributes.irfi'



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

create temporary table tmp_rog_accession_mapping as
    select SI.rog, S.reftaxid as taxid, array_to_string(array_accum(dblabel || ':' || refvalue), '|') as accessions
    from xml_xref_sequences as S
    inner join irefindex_rog2rogid as SI
        on S.refsequence || S.reftaxid = SI.rogid
    group by SI.rog, S.reftaxid;

analyze tmp_rog_accession_mapping;

create temporary table tmp_rog_accessions as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.xref=>|' || accessions || '|'
    from tmp_rog_accession_mapping;

\copy tmp_rog_accessions to '<directory>/_COL__ROG_xref.irft'

-- ROG identifiers with taxonomy identifiers.

create temporary table tmp_rogids as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.rogid=>|' || SI.rogid || '|'
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    group by SI.rog, SI.rogid;

\copy tmp_rogids to '<directory>/_ONE__EXT__ROG_ROGID.irft'

-- ROG integer identifiers with taxonomy identifiers and a selection of names.
-- NOTE: The names used do not necessarily replicate those found in previous
-- NOTE: iRefIndex releases.

create temporary table tmp_rog_fullnames_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct upper("synonym")), '|') as names
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join tmp_all_gene_synonym_rogids as S
        on SI.rogid = S.rogid
    group by SI.rog, SI.rogid;

analyze tmp_rog_fullnames_mapping;

create temporary table tmp_rog_fullnames as
    select rog || '|+|i.taxid=>' || taxid
        || '|+|i.interactor_description=>|' || names || '|'
    from tmp_rog_fullnames_mapping;

analyze tmp_rog_fullnames;

\copy tmp_rog_fullnames to '<directory>/_ROG_fullname.irft'



-- ROG integer identifiers mapped to display names.
-- Names can be one of the following: UniProt identifiers, gene symbols, gene
-- synonyms, locustags, UniProt accessions, other identifiers (GenBank, FlyBase,
-- RefSeq), or ROG identifier.

-- NOTE: Need to fully support the above list of identifier types.

create temporary table tmp_uniprot_combined as
    select SI.rog,
        array_to_string(array_accum(U.uniprotid), '|') as uniprotids
    from irefindex_rog2rogid as SI
    left outer join tmp_uniprot_rogids as U
        on U.rogid = SI.rogid
    group by SI.rog;

analyze tmp_uniprot_combined;

create temporary table tmp_gene_symbols_combined as
    select SI.rog,
        array_to_string(array_accum(G.symbol), '|') as symbols
    from irefindex_rog2rogid as SI
    left outer join tmp_gene_symbol_rogids as G
        on G.rogid = SI.rogid
    group by SI.rog;

analyze tmp_gene_symbols_combined;

create temporary table tmp_all_gene_synonyms_combined as
    select SI.rog,
        array_to_string(array_accum(S.synonym), '|') as synonyms
    from irefindex_rog2rogid as SI
    left outer join tmp_all_gene_synonym_rogids as S
        on S.rogid = SI.rogid
    group by SI.rog;

analyze tmp_all_gene_synonyms_combined;

create temporary table tmp_all_identifiers_combined as
    select SI.rog,
        array_to_string(array_accum(I.dblabel || ':' || replace(I.refvalue, '|', '_')), '|') as identifiers
    from irefindex_rog2rogid as SI
    left outer join irefindex_all_rogid_identifiers as I
        on I.rogid = SI.rogid
    group by SI.rog;

analyze tmp_all_identifiers_combined;

create temporary table tmp_display_name_mapping as
    select I.rog, case
        when uniprotids <> '' then uniprotids
        when symbols <> '' then symbols
        when synonyms <> '' then synonyms
        else identifiers
        end as name
    from tmp_all_identifiers_combined as I
    left outer join tmp_uniprot_combined as U
        on U.rog = I.rog
    left outer join tmp_gene_symbols_combined as G
        on G.rog = I.rog
    left outer join tmp_all_gene_synonyms_combined as S
        on S.rog = I.rog;

analyze tmp_display_name_mapping;

create temporary table tmp_display_names as
    select rog || '|+|i.displayLabel=>|' || upper(name)
    from tmp_display_name_mapping
    where name <> '';

\copy tmp_display_names to '<directory>/_ROG_displaylabel.irft'



-- ROG integer identifiers mapped to UniProt accessions with taxonomy details.

create temporary table tmp_uniprot_accessions_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(refvalue), '|') as accessions
    from irefindex_rog2rogid as SI
    inner join irefindex_rogid_identifiers as I
        on SI.rogid = I.rogid
        and dblabel = 'uniprotkb'
    group by SI.rog, SI.rogid;

analyze tmp_uniprot_accessions_mapping;

create temporary table tmp_uniprot_accessions as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.UniProt_Ac=>|' || accessions
    from tmp_uniprot_accessions_mapping;

\copy tmp_uniprot_accessions to '<directory>/_ROG__EXT__EXPORT_UniProt_Ac.irft'

-- ROG integer identifiers mapped to UniProt identifiers with taxonomy details.

create temporary table tmp_uniprot_names as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.UniProt_ID=>|' || uniprotid
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join tmp_uniprot_rogids as U
        on R.rogid = U.rogid
    group by SI.rog, SI.rogid, uniprotid;

\copy tmp_uniprot_names to '<directory>/_ROG__EXT__EXPORT_UniProt_ID.irft'

-- ROG integer identifiers mapped to gene symbols with taxonomy details.

create temporary table tmp_gene_symbols as
    select SI.rog || '|+|i.taxid=>' || substring(SI.rogid from 28) || '|+|i.geneSymbol=>|' || symbol
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    inner join gene_info as I
        on G.geneid = I.geneid
    group by SI.rog, SI.rogid, symbol;

\copy tmp_gene_symbols to '<directory>/_ROG__EXT__EXPORT__TAX_geneSymbol.irft'

-- ROG integer identifiers mapped to RefSeq accessions with taxonomy details.

create temporary table tmp_refseq_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(refvalue), '|') as accessions
    from irefindex_rog2rogid as SI
    inner join irefindex_rogid_identifiers as R
        on SI.rogid = R.rogid
        and dblabel = 'refseq'
    group by SI.rog, SI.rogid;

analyze tmp_refseq_mapping;

create temporary table tmp_refseq as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.RefSeq_Ac=>|' || accessions
    from tmp_refseq_mapping;

\copy tmp_refseq to '<directory>/_ROG__EXT__EXPORT_RefSeq_Ac.irft'

-- ROG integer identifiers mapped to gene identifiers with taxonomy details.

create temporary table tmp_geneids_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, geneid
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    group by SI.rog, SI.rogid, geneid;

analyze tmp_geneids_mapping;

create temporary table tmp_geneids as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.geneID=>|' || geneid || '|'
    from tmp_geneids_mapping;

\copy tmp_geneids to '<directory>/_EXT__EXPORT__ROG_geneID.irft'

-- ROG integer identifiers mapped to molecular weights with taxonomy details.

create temporary table tmp_mw_mapping as
    select distinct SI.rog, substring(SI.rogid from 28) as taxid, mw
    from irefindex_rog2rogid as SI
    inner join irefindex_rogid_identifiers as I
        on SI.rogid = I.rogid
    inner join uniprot_proteins as U
        on I.refvalue = U.accession
        and I.dblabel = 'uniprotkb';

analyze tmp_mw_mapping;

create temporary table tmp_mw as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.mw=>|' || mw || '|'
    from tmp_mw_mapping;

\copy tmp_mw to '<directory>/_EXT__RANGE__ROG_mass.irft'

-- ROG integer identifiers mapped to IPI identifiers with taxonomy details.

create temporary table tmp_ipi_mapping as
    select distinct SI.rog, substring(SI.rogid from 28) as taxid, substring(refvalue from 'IPI[[:digit:]]*') as refvalue
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_all_rogid_identifiers as I
        on R.rogid = I.rogid
        and dblabel = 'ipi';

analyze tmp_ipi_mapping;

create temporary table tmp_ipi as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.ipi=>|' || refvalue
    from tmp_ipi_mapping;

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

create temporary table tmp_go_functions_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct term), '|') as functions
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    inner join gene2go as GG
        on G.geneid = GG.geneid
        and GG.category = 'Function'
    group by SI.rog, SI.rogid;

analyze tmp_go_functions_mapping;

create temporary table tmp_go_functions as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.function=>|' || functions
    from tmp_go_functions_mapping;

\copy tmp_go_functions to '<directory>/_EXT__ROG_Function.irft'

create temporary table tmp_go_components_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct term), '|') as components
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    inner join gene2go as GG
        on G.geneid = GG.geneid
        and GG.category = 'Component'
    group by SI.rog, SI.rogid;

analyze tmp_go_components_mapping;

create temporary table tmp_go_components as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.component=>|' || components
    from tmp_go_components_mapping;

\copy tmp_go_functions to '<directory>/_EXT__ROG_Component.irft'

create temporary table tmp_go_processes_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct term), '|') as processes
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    inner join gene2go as GG
        on G.geneid = GG.geneid
        and GG.category = 'Process'
    group by SI.rog, SI.rogid;

analyze tmp_go_processes_mapping;

create temporary table tmp_go_processes as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.process=>|' || processes
    from tmp_go_processes_mapping;

\copy tmp_go_functions to '<directory>/_EXT__ROG_Process.irft'

-- ROG integer identifiers mapped to chromosome information with taxonomy details.

create temporary table tmp_chromosomes_mapping as
    select distinct SI.rog, substring(SI.rogid from 28) as taxid, chromosome
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    inner join gene_info as GI
        on G.geneid = GI.geneid;

analyze tmp_chromosomes_mapping;

create temporary table tmp_chromosomes as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.chromosome=>|' || chromosome || '|'
    from tmp_chromosomes_mapping;

\copy tmp_chromosomes to '<directory>/_ROG_chromosome.irft'

-- ROG integer identifiers mapped to maplocation information with taxonomy details.

create temporary table tmp_maplocations_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(maplocation), '|') as maplocations
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_gene2rog as G
        on R.rogid = G.rogid
    inner join gene_maplocations as GM
        on G.geneid = GM.geneid
    group by SI.rog, SI.rogid;

analyze tmp_maplocations_mapping;

create temporary table tmp_maplocations as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.maplocation=>|' || maplocations || '|'
    from tmp_maplocations_mapping;

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

create temporary table tmp_shortlabels_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct upper(name)), '|') as names
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join xml_names_interactor_names as N
        on (R.source, R.filename, R.entry, R.interactorid) =
           (N.source, N.filename, N.entry, N.interactorid)
        and nametype = 'shortLabel'
    group by SI.rog, SI.rogid;

analyze tmp_shortlabels_mapping;

create temporary table tmp_shortlabels as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.interactor_shortlbl=>|' || names || '|'
    from tmp_shortlabels_mapping;

\copy tmp_shortlabels to '<directory>/_ROG_ShortLabel.irft'

-- ROG integer identifiers mapped to interactor synonyms with taxonomy details.
-- NOTE: Adopting the previous spelling of the attribute name.

create temporary table tmp_synonyms_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(upper("synonym")), '|') as synonyms
    from irefindex_rog2rogid as SI
    inner join tmp_all_gene_synonym_rogids as S
        on SI.rogid = S.rogid
    group by SI.rog, SI.rogid
    having count("synonym") > 0;

analyze tmp_synonyms_mapping;

create temporary table tmp_synonyms as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.interactor_synonims=>|' || synonyms || '|'
    from tmp_synonyms_mapping;

\copy tmp_synonyms to '<directory>/_ROG_synonyms.irft'

-- ROG integer identifiers mapped to interactor aliases with taxonomy details.

create temporary table tmp_aliases_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct upper(name)), '|') as names
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join xml_names_interactor_names as N
        on (R.source, R.filename, R.entry, R.interactorid) =
           (N.source, N.filename, N.entry, N.interactorid)
        and nametype = 'alias'
    group by SI.rog, SI.rogid;

analyze tmp_aliases_mapping;

create temporary table tmp_aliases as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.interactor_alias=>|' || names || '|'
    from tmp_aliases_mapping;

\copy tmp_aliases to '<directory>/_ROG_alias.irft'

-- Interaction references mapped to RIG identifiers.

create temporary table tmp_interaction2rig as
    select refvalue, rigid
    from xml_xref_interactions as I
    inner join irefindex_rigids as R
        on (I.source, I.filename, I.entry, I.interactionid) = 
           (R.source, R.filename, R.entry, R.interactionid);

\copy tmp_interaction2rig to '<directory>/_EXT__RIG_src_intxn_id.irft'

-- RIG identifier mapping.

create temporary table tmp_rig2rigid as
    select '|' || rig || '|+|' || I.rigid
    from irefindex_rig2rigid as I
    inner join irefindex_rigids as R
        on I.rigid = R.rigid
    group by rig, I.rigid;

\copy tmp_rig2rigid to '<directory>/_ONE__EXT__RIG_RIGID.irft'

-- Original references for ROG integer identifiers.

create temporary table tmp_original_references_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct originalrefvalue), '|') as refvalues
    from irefindex_rog2rogid as SI
    inner join irefindex_rogids as R
        on SI.rogid = R.rogid
    inner join irefindex_assignments as A
        on (R.source, R.filename, R.entry, R.interactorid) =
           (A.source, A.filename, A.entry, A.interactorid)
    group by SI.rog, SI.rogid;

analyze tmp_original_references_mapping;

create temporary table tmp_original_references as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.originalReferences=>|' || refvalues
    from tmp_original_references_mapping;

\copy tmp_original_references to '<directory>/_ROG_originalReference.irft'

-- Disease groups data.

create temporary table tmp_dig2rog as
    select D.digid, R.rogid, diseaseomimid, title
    from dig_diseases as D
    inner join irefindex_gene2rog as G
        on D.geneid = G.geneid
    inner join irefindex_rogids as R
        on G.rogid = R.rogid;

analyze tmp_dig2rog;

create temporary table tmp_omim_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct diseaseomimid), '|') as omimids
    from irefindex_rog2rogid as SI
    inner join tmp_dig2rog as R
        on SI.rogid = R.rogid
    where diseaseomimid <> 0
    group by SI.rog, SI.rogid;

analyze tmp_omim_mapping;

create temporary table tmp_omim as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.omim=>|' || omimids
    from tmp_omim_mapping;

\copy tmp_omim to '<directory>/_EXT__ROG_omim.irft'

create temporary table tmp_digid_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct digid), '|') as digids
    from irefindex_rog2rogid as SI
    inner join tmp_dig2rog as R
        on SI.rogid = R.rogid
    where digid <> 0
    group by SI.rog, SI.rogid;

analyze tmp_digid_mapping;

create temporary table tmp_digid as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.digid=>|' || digids
    from tmp_digid_mapping;

\copy tmp_digid to '<directory>/_EXT__ROG_digid.irft'

create temporary table tmp_digtitle_mapping as
    select SI.rog, substring(SI.rogid from 28) as taxid, array_to_string(array_accum(distinct title), '|') as titles
    from irefindex_rog2rogid as SI
    inner join tmp_dig2rog as R
        on SI.rogid = R.rogid
    group by SI.rog, SI.rogid;

analyze tmp_digtitle_mapping;

create temporary table tmp_digtitle as
    select rog || '|+|i.taxid=>' || taxid || '|+|i.dig_title=>|' || titles
    from tmp_digtitle_mapping;

\copy tmp_digtitle to '<directory>/_ROG_dig_title.irft'



-- A pairwise mapping of ROG integer identifiers for each interaction.
-- This can then be processed by the irdata_convert_graph.py tool.

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

    group by I.rog, I2.rog;

\copy tmp_graph to '<directory>/graph'

-- ROG integer identifiers and their neighbours in the graph.

create temporary table tmp_graph_neighbours as
    select rogA || '|+|' || array_to_string(array_accum(rogB), '+')
    from tmp_graph
    group by rogA;

\copy tmp_graph_neighbours to '<directory>/rog2full_neighbourhood.irfm'

-- ROG integer identifiers mapped to their degree in the graph.

create temporary table tmp_graph_degree_index_mapping as
    select rogA as rog, count(rogB) as degree
    from tmp_graph
    group by rogA;

analyze tmp_graph_degree_index_mapping;

create temporary table tmp_graph_degree_index as
    select rog || '|+|i.taxid=>-10|+|i.overall_degree=>|' || degree || '|'
    from tmp_graph_degree_index_mapping;

\copy tmp_graph_degree_index to '<directory>/_EXT__ROG_overall_degree.irft'



-- All the ROG information is actually combined to make the records stored
-- inside the ROG archives.

create temporary table tmp_rog_details as
    select SI.rog
        ||                                              '|++|i.taxid=>' || substring(SI.rogid from 28)
        || case when S.accessions is not null then      '|+|i.xref=>|' || S.accessions else '' end                  || '|'
        || case when CI.rog is not null then            '|+|i.canonical_rog=>|' || CI.rog else '' end
        || case when GS.synonyms is not null then       '|+|i.interactor_description=>|' || GS.synonyms else '' end || '|'
        || case when DN.name is not null then           '|+|i.displayLabel=>|' || DN.name else '' end
        || case when UA.accessions is not null then     '|+|i.UniProt_Ac=>|' || UA.accessions else '' end
        || case when U.uniprotids is not null then      '|+|i.UniProt_ID=>|' || U.uniprotids else '' end
        || case when G.symbols is not null then         '|+|i.geneSymbol=>|' || G.symbols else '' end
        || case when RA.accessions is not null then     '|+|i.RefSeq_Ac=>|' || RA.accessions else '' end
        ||                                              '|+|i.rogid=>|' || SI.rogid                                 || '|'
        || case when FN.names is not null then          '|+|i.interactor_description=>|' || FN.names else '' end    || '|'
        || case when GI.geneid is not null then         '|+|i.geneID=>|' || GI.geneid else '' end
        || case when MW.mw is not null then             '|+|i.mw=>|' || MW.mw else '' end                           || '|'
        || case when IPI.refvalue is not null then      '|+|i.ipi=>|' || IPI.refvalue else '' end
        || case when GF.functions is not null then      '|+|i.function=>|' || GF.functions else '' end
        || case when GC.components is not null then     '|+|i.component=>|' || GC.components else '' end
        || case when GP.processes is not null then      '|+|i.process=>|' || GP.processes else '' end
        || case when C.chromosome is not null then      '|+|i.chromosome=>|' || C.chromosome else '' end            || '|'
        || case when M.maplocations is not null then    '|+|i.maplocation=>|' || M.maplocations else '' end         || '|'
        || case when SL.names is not null then          '|+|i.interactor_shortlbl=>|' || SL.names else '' end       || '|'
        || case when SM.synonyms is not null then       '|+|i.interactor_synonims=>|' || SM.synonyms else '' end    || '|'
        || case when A.names is not null then           '|+|i.interactor_alias=>|' || A.names else '' end           || '|'
        || case when O.refvalues is not null then       '|+|i.originalReferences=>|' || O.refvalues else '' end
        || case when OM.omimids is not null then        '|+|i.omim=>|' || OM.omimids else '' end
        || case when DG.digids is not null then         '|+|i.digid=>|' || DG.digids else '' end
        || case when DT.titles is not null then         '|+|i.dig_title=>|' || DT.titles else '' end
        ||                                              '|+|i.overall_degree=>|' || GD.degree                       || '|'
        || '|'

    -- ROG and integer identifier for the specific interactor.

    from irefindex_rog2rogid as SI

    -- ROG and integer identifier for the canonical interactor.

    inner join irefindex_rogids_canonical as CR
        on SI.rogid = CR.rogid
    inner join irefindex_rog2rogid as CI
        on CR.crogid = CI.rogid

    -- Cross-references.

    left outer join tmp_rog_accession_mapping as S
        on SI.rog = S.rog

    -- UniProt identifiers.

    left outer join tmp_uniprot_combined as U
        on SI.rog = U.rog
        and U.uniprotids <> ''

    -- Gene symbols and synonyms.

    left outer join tmp_gene_symbols_combined as G
        on SI.rog = G.rog
        and G.symbols <> ''
    left outer join tmp_all_gene_synonyms_combined as GS
        on SI.rog = GS.rog
        and GS.synonyms <> ''

    -- Display names.

    left outer join tmp_display_name_mapping as DN
        on SI.rog = DN.rog
        and DN.name <> ''

    -- UniProt accessions.

    left outer join tmp_uniprot_accessions_mapping as UA
        on SI.rog = UA.rog

    -- RefSeq accessions.

    left outer join tmp_refseq_mapping as RA
        on SI.rog = RA.rog

    -- Full names.

    left outer join tmp_rog_fullnames_mapping as FN
        on SI.rog = FN.rog

    -- Gene identifiers

    left outer join tmp_geneids_mapping as GI
        on SI.rog = GI.rog

    -- Molecular weight.

    left outer join tmp_mw_mapping as MW
        on SI.rog = MW.rog

    -- IPI accessions.

    left outer join tmp_ipi_mapping as IPI
        on SI.rog = IPI.rog

    -- GO functions.

    left outer join tmp_go_functions_mapping as GF
        on SI.rog = GF.rog

    -- GO components.

    left outer join tmp_go_components_mapping as GC
        on SI.rog = GC.rog

    -- GO processes.

    left outer join tmp_go_processes_mapping as GP
        on SI.rog = GP.rog

    -- Chromosomes.

    left outer join tmp_chromosomes_mapping as C
        on SI.rog = C.rog

    -- Maplocations.

    left outer join tmp_maplocations_mapping as M
        on SI.rog = M.rog

    -- Shortlabels.

    left outer join tmp_shortlabels_mapping as SL
        on SI.rog = SL.rog

    -- Synonyms.

    left outer join tmp_synonyms_mapping as SM
        on SI.rog = SM.rog

    -- Aliases.

    left outer join tmp_aliases_mapping as A
        on SI.rog = A.rog

    -- Original references.

    left outer join tmp_original_references_mapping as O
        on SI.rog = O.rog

    -- Disease group references.

    left outer join tmp_omim_mapping as OM
        on SI.rog = OM.rog
    left outer join tmp_digid_mapping as DG
        on SI.rog = DG.rog
    left outer join tmp_digtitle_mapping as DT
        on SI.rog = DT.rog

    -- Degrees.

    inner join tmp_graph_degree_index_mapping as GD
        on SI.rog = GD.rog;

\copy tmp_rog_details to '<directory>/rogAttributes.irfi'

rollback;
