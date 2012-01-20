begin;

-- Ambiguous references.

insert into irefindex_ambiguity
    select source, filename, entry, interactorid, reftype, refsequences
    from (
        select source, filename, entry, interactorid, reftype, count(distinct refsequence) as refsequences
        from xml_xref_interactor_sequences
        group by source, filename, entry, interactorid, reftype
        ) as X;

create index irefindex_ambiguity_reftype_sequences on irefindex_ambiguity (reftype, refsequences);

analyze irefindex_ambiguity;

-- Unambiguous primary and secondary references.

create temporary table tmp_unambiguous_references as
    select I.source, I.filename, I.entry, I.interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        I.reftype, array_array_accum(distinct array[[I.dblabel, I.refvalue]]) as identifiers,
        cast('unambiguous' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences = 1
    group by I.source, I.filename, I.entry, I.interactorid, I.reftype;

analyze tmp_unambiguous_references;

-- Ambiguous primary and secondary references disambiguated by interactor
-- sequence information.

-- Since interactor descriptions should only provide a single sequence, at most
-- one ambiguous sequence database sequence can match. This will potentially
-- provide one correspondence per reference type (one primary reference and one
-- secondary reference) involving a matching sequence.

-- NOTE: This will eventually need to distinguish between gene and non-gene
-- NOTE: references and to exclude gene references for which the canonical
-- NOTE: representative will instead be chosen.

create temporary table tmp_unambiguous_matching_sequence_references as
    select I.source, I.filename, I.entry, I.interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        I.reftype, array_array_accum(distinct array[[I.dblabel, I.refvalue]]) as identifiers,
        cast('matching sequence' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences > 1
        and sequence = refsequence
    group by I.source, I.filename, I.entry, I.interactorid, I.reftype;

create index tmp_unambiguous_matching_sequence_references_index on
    tmp_unambiguous_matching_sequence_references (source, filename, entry, interactorid);

analyze tmp_unambiguous_matching_sequence_references;

-- Null primary and secondary references where an interactor sequence is
-- available but not any sequence database sequence.

create temporary table tmp_unambiguous_null_references as
    select I.source, I.filename, I.entry, I.interactorid, I.sequence,
        taxid, cast(null as varchar[]) as sequencelinks,
        I.reftype, cast(null as varchar[][]) as identifiers,
        cast('interactor sequence' as varchar) as method
    from xml_xref_interactor_sequences as I
    inner join irefindex_ambiguity as A
        on (I.source, I.filename, I.entry, I.interactorid, I.reftype)
            = (A.source, A.filename, A.entry, A.interactorid, A.reftype)
    where A.refsequences = 0
        and I.sequence is not null
    group by I.source, I.filename, I.entry, I.interactorid, I.reftype, I.taxid, I.sequence;

analyze tmp_unambiguous_null_references;

-- Combine the different interactors.

create temporary table tmp_primary_references as
    select *
    from tmp_unambiguous_references
    where reftype = 'primaryRef'
    union all
    select *
    from tmp_unambiguous_matching_sequence_references
    where reftype = 'primaryRef';

analyze tmp_primary_references;

create temporary table tmp_secondary_references as
    select *
    from tmp_unambiguous_references
    where reftype = 'secondaryRef'
    union all
    select *
    from tmp_unambiguous_matching_sequence_references
    where reftype = 'secondaryRef';

analyze tmp_secondary_references;

insert into irefindex_assignments
    select *
    from tmp_primary_references
    union all
    select *
    from tmp_secondary_references
    where (source, filename, entry, interactorid) not in (
        select source, filename, entry, interactorid
        from tmp_primary_references);

analyze irefindex_assignments;

insert into irefindex_assignments
    select N.*
    from tmp_unambiguous_null_references as N
    left outer join irefindex_assignments as A
        on (N.source, N.filename, N.entry, N.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where N.reftype = 'primaryRef'
        and A.interactorid is null;

insert into irefindex_assignments
    select N.*
    from tmp_unambiguous_null_references as N
    left outer join irefindex_assignments as A
        on (N.source, N.filename, N.entry, N.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where N.reftype = 'secondaryRef'
        and A.interactorid is null;

analyze irefindex_assignments;

-- Remaining unassigned interactors.

insert into irefindex_unassigned
    select I.source, I.filename, I.entry, I.interactorid,
        count(distinct I.sequence) as sequences, count(distinct refsequence) as refsequences
    from xml_xref_interactor_sequences as I
    left outer join irefindex_assignments as A
        on (I.source, I.filename, I.entry, I.interactorid) =
            (A.source, A.filename, A.entry, A.interactorid)
    where A.interactorid is null
    group by I.source, I.filename, I.entry, I.interactorid;

analyze irefindex_unassigned;

commit;
