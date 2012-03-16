begin;

-- Ambiguous references.
-- For each reference type for each interactor, note the ambiguity of the
-- references.

insert into irefindex_ambiguity
    select source, filename, entry, interactorid, reftype,
        count(distinct refsequence) as refsequences, count(distinct reftaxid) as reftaxids
    from xml_xref_interactor_sequences
    group by source, filename, entry, interactorid, reftype;

create index irefindex_ambiguity_reftype_sequences on irefindex_ambiguity (reftype, refsequences);

analyze irefindex_ambiguity;

-- Unambiguous primary and secondary references.

create temporary table tmp_unambiguous_references as
    select distinct I.source, I.filename, I.entry, I.interactorid, I.taxid as originaltaxid,
        refsequence as sequence, reftaxid as taxid,
        sequencelink, I.reftype, I.reftypelabel, I.dblabel, I.refvalue,
        originaldblabel, originalrefvalue, missing,
        cast('unambiguous' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences = 1
        and A.reftaxids = 1
        and refsequence is not null;

analyze tmp_unambiguous_references;

-- Primary and secondary references with unambiguous sequence information and
-- ambiguous taxonomy information disambiguated by taxonomy.

create temporary table tmp_unambiguous_matching_taxonomy_references as
    select distinct I.source, I.filename, I.entry, I.interactorid, I.taxid as originaltaxid,
        refsequence as sequence, reftaxid as taxid,
        sequencelink, I.reftype, I.reftypelabel, I.dblabel, I.refvalue,
        originaldblabel, originalrefvalue, missing,
        cast('matching taxonomy' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences = 1
        and A.reftaxids > 1
        and taxid = reftaxid
        and refsequence is not null;

create index tmp_unambiguous_matching_taxonomy_references_index on
    tmp_unambiguous_matching_taxonomy_references (source, filename, entry, interactorid);

analyze tmp_unambiguous_matching_taxonomy_references;

-- Ambiguous primary and secondary references disambiguated by interactor
-- sequence information.

-- Since interactor descriptions should only provide a single sequence, at most
-- one ambiguous sequence database sequence can match. This will potentially
-- provide one correspondence per reference type (one primary reference and one
-- secondary reference) involving a matching sequence.

create temporary table tmp_unambiguous_matching_sequence_references as
    select distinct I.source, I.filename, I.entry, I.interactorid, I.taxid as originaltaxid,
        refsequence as sequence, reftaxid as taxid,
        sequencelink, I.reftype, I.reftypelabel, I.dblabel, I.refvalue,
        originaldblabel, originalrefvalue, missing,
        cast('matching sequence' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences > 1
        and A.reftaxids = 1
        and sequence = refsequence;

create index tmp_unambiguous_matching_sequence_references_index on
    tmp_unambiguous_matching_sequence_references (source, filename, entry, interactorid);

analyze tmp_unambiguous_matching_sequence_references;

-- Null primary and secondary references where an interactor sequence is
-- available but not any sequence database sequence.

create temporary table tmp_unambiguous_null_references as
    select I.source, I.filename, I.entry, I.interactorid, I.taxid as originaltaxid,
        I.sequence, taxid,
        cast(null as varchar) as sequencelink, I.reftype, I.reftypelabel, I.dblabel, I.refvalue,
        originaldblabel, originalrefvalue, missing,
        cast('interactor sequence' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences = 0
        and I.sequence is not null;

analyze tmp_unambiguous_null_references;

-- Arbitrarily assigned references.

-- NOTE: This will eventually need to distinguish between gene and non-gene
-- NOTE: references and to exclude gene references for which the canonical
-- NOTE: representative will instead be chosen.

create temporary table tmp_arbitrary_references as
    select distinct S.source, S.filename, S.entry, S.interactorid, S.taxid as originaltaxid,
        refdetails[1] as sequence, cast(refdetails[2] as integer) as taxid,
        sequencelink, S.reftype, S.reftypelabel, S.dblabel, S.refvalue,
        originaldblabel, originalrefvalue, missing,
        cast('arbitrary' as varchar) as method
    from (

        -- Get the highest sorted sequence for each ambiguous reference.
        -- Note that this requires an appropriate locale so that the appropriate
        -- result is obtained from the max function.

        select S.source, S.filename, S.entry, S.interactorid, S.reftype,
            max(array[refsequence, cast(reftaxid as varchar)]) as refdetails
        from xml_xref_interactor_sequences as S
        inner join irefindex_ambiguity as A
            on (S.source, S.filename, S.entry, S.interactorid, S.reftype) =
                (A.source, A.filename, A.entry, A.interactorid, A.reftype)
        where refsequences > 1
            and refsequence is not null
        group by S.source, S.filename, S.entry, S.interactorid, S.reftype

        ) as X
    inner join xml_xref_interactor_sequences as S
        on (S.source, S.filename, S.entry, S.interactorid, S.reftype, S.refsequence) =
            (X.source, X.filename, X.entry, X.interactorid, X.reftype, refdetails[1]);

-- Combine the different interactors.

create temporary table tmp_primary_references as
    select *
    from tmp_unambiguous_references
    where reftype = 'primaryRef'
    union all
    select *
    from tmp_unambiguous_matching_sequence_references
    where reftype = 'primaryRef'
    union all
    select *
    from tmp_unambiguous_matching_taxonomy_references
    where reftype = 'primaryRef';

analyze tmp_primary_references;

create temporary table tmp_secondary_references as
    select *
    from tmp_unambiguous_references
    where reftype = 'secondaryRef'
    union all
    select *
    from tmp_unambiguous_matching_sequence_references
    where reftype = 'secondaryRef'
    union all
    select *
    from tmp_unambiguous_matching_taxonomy_references
    where reftype = 'secondaryRef';

analyze tmp_secondary_references;

-- Take unambiguous primary reference assignments and all additional secondary
-- references.

insert into irefindex_assignments
    select *
    from tmp_primary_references
    union all
    select S.*
    from tmp_secondary_references as S
    left outer join tmp_primary_references as P
        on (S.source, S.filename, S.entry, S.interactorid) =
            (P.source, P.filename, P.entry, P.interactorid)
    where P.interactorid is null;

analyze irefindex_assignments;

-- Take additional unambiguous primary references employing an interaction
-- record sequence.

insert into irefindex_assignments
    select N.*
    from tmp_unambiguous_null_references as N
    left outer join irefindex_assignments as A
        on (N.source, N.filename, N.entry, N.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where N.reftype = 'primaryRef'
        and A.interactorid is null;

-- Take additional unambiguous secondary references employing an interaction
-- record sequence.

insert into irefindex_assignments
    select N.*
    from tmp_unambiguous_null_references as N
    left outer join irefindex_assignments as A
        on (N.source, N.filename, N.entry, N.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where N.reftype = 'secondaryRef'
        and A.interactorid is null;

analyze irefindex_assignments;

-- Take additional arbitrarily assigned primary references.

insert into irefindex_assignments
    select N.*
    from tmp_arbitrary_references as N
    left outer join irefindex_assignments as A
        on (N.source, N.filename, N.entry, N.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where N.reftype = 'primaryRef'
        and A.interactorid is null;

-- Take additional arbitrarily assigned secondary references.

insert into irefindex_assignments
    select N.*
    from tmp_arbitrary_references as N
    left outer join irefindex_assignments as A
        on (N.source, N.filename, N.entry, N.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where N.reftype = 'secondaryRef'
        and A.interactorid is null;

analyze irefindex_assignments;

-- Remaining unassigned interactors.

insert into irefindex_unassigned
    select I.source, I.filename, I.entry, I.interactorid, I.taxid, I.sequence,
        count(distinct refsequence) as refsequences
    from xml_xref_interactor_sequences as I
    left outer join irefindex_assignments as A
        on (I.source, I.filename, I.entry, I.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where A.interactorid is null
    group by I.source, I.filename, I.entry, I.interactorid, I.taxid, I.sequence;

analyze irefindex_unassigned;

-- Preferred assignments.
-- The above assignments includes potentially multiple paths to the same
-- sequence for each interactor. By nominating preferred sequence links, a
-- single path can be chosen.

create temporary table tmp_sequencelinks as
    select distinct sequencelink, priority
    from (
        select sequencelink, case when sequencelink like '%entrezgene%' then 'B' else 'A' end as priority
        from xml_xref_sequences
        ) as X;

insert into irefindex_assignments_preferred
    select A.source, A.filename, A.entry, A.interactorid, A.sequencelink, A.dblabel, A.refvalue
    from (

        -- Use the priority ordering defined above to select a minimum (best)
        -- priority, selecting an arbitrary identifier where multiple paths to
        -- the sequence have the same priority.

        select source, filename, entry, interactorid, min(array[priority, A.sequencelink, dblabel, refvalue]) as preferred
        from irefindex_assignments as A
        inner join tmp_sequencelinks as S
            on A.sequencelink = S.sequencelink
        group by source, filename, entry, interactorid
        ) as P
        inner join irefindex_assignments as A
        on (A.source, A.filename, A.entry, A.interactorid, A.sequencelink, A.dblabel, A.refvalue) =
           (P.source, P.filename, P.entry, P.interactorid, preferred[2], preferred[3], preferred[4]);

analyze irefindex_assignments_preferred;

-- Scoring of assignments.

insert into irefindex_assignment_scores
    select distinct A.source, A.filename, A.entry, A.interactorid,
        array_to_string(array[
            case when reftype = 'primaryRef' then 'P' else '' end,
            case when reftype = 'secondaryRef' then 'S' else '' end,
            case when A.sequencelink in ('uniprotkb/non-primary', 'uniprotkb/isoform-non-primary-unexpected') then 'U' else '' end,
            case when A.sequencelink = 'refseq/version-discarded' then 'V' else '' end,
            case when originaltaxid <> taxid then 'T' else '' end,
            case when A.sequencelink like 'entrezgene%' then 'G' else '' end,
            case when originaldblabel <> A.dblabel then 'D' else '' end,
            case when A.sequencelink like 'uniprotkb/sgd%' then 'M' else '' end, -- M currently not generally tracked (typographical modification)
            case when method <> 'unambiguous' then '+' else '' end,
            case when method = 'matching sequence' then 'O' else '' end,
            case when method = 'matching taxonomy' then 'X' else '' end,
            '', -- ?
            case when method = 'arbitrary' then 'L' else '' end,
            case when A.dblabel = 'genbank_protein_gi' then 'I' else '' end,
            case when missing then 'E' else '' end,
            '', -- Y score not yet supported (refers to obsolete assignment)
            '', -- N score not yet supported (refers to new assignment)
            case when reftypelabel = 'see-also' then 'Q' else '' end
            ], '') as score
    from irefindex_assignments_preferred as P
    inner join irefindex_assignments as A
        on (A.source, A.filename, A.entry, A.interactorid, A.sequencelink, A.dblabel, A.refvalue) =
           (P.source, P.filename, P.entry, P.interactorid, P.sequencelink, P.dblabel, P.refvalue);

analyze irefindex_assignment_scores;

-- ROG identifiers.
-- Since more than one link to a sequence database may exist, the records must
-- be made distinct. The taxid is exposed here for convenience since it can be
-- useful to be able to map interactors to taxids directly without having to
-- extract them from ROG identifiers.

insert into irefindex_rogids
    select distinct source, filename, entry, interactorid, sequence || taxid as rogid,
        taxid, method
    from irefindex_assignments
    where sequence is not null
        and taxid is not null;

create index irefindex_rogids_rogid on irefindex_rogids(rogid);
analyze irefindex_rogids;

-- Database identifiers corresponding to ROG identifiers.
-- Since reference database and interaction database identifiers comprise the
-- content of the assignments table, it is used instead of the identifier
-- sequences table for a definitive mapping of known ROG identifiers to database
-- identifiers.

insert into irefindex_rogid_identifiers
    select distinct rogid, dblabel, refvalue
    from irefindex_rogids as R
    inner join irefindex_assignments as A
        on (R.source, R.filename, R.entry, R.interactorid) =
           (A.source, A.filename, A.entry, A.interactorid);

analyze irefindex_rogid_identifiers;

-- Determine the complete interactions.

insert into irefindex_interactions_complete
    select I.source, I.filename, I.entry, I.interactionid,
        count(I.interactorid) = count(R.rogid) as complete
        from xml_interactors as I
        left outer join irefindex_rogids as R
            on (I.source, I.filename, I.entry, I.interactorid) =
               (R.source, R.filename, R.entry, R.interactorid)
        group by I.source, I.filename, I.entry, I.interactionid;

analyze irefindex_interactions_complete;

commit;
