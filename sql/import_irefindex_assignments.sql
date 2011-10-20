begin;

-- Unambiguous primary or secondary references.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('unambiguous' as varchar) as method
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Ambiguous references.

create temporary table tmp_ambiguous_references as
    select source, filename, entry, interactorid
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) > 1;

-- Ambiguous references resolved by selecting records with identical interaction
-- and sequence database sequences, thus excluding the above completely
-- unambiguous references.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_matching_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('matching' as varchar) as method
    from xml_xref_sequences
    where sequence = refsequence
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from tmp_ambiguous_references
            )
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Ambiguous references resolved by selecting records providing a valid primary
-- reference.

create temporary table tmp_unambiguous_primary_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('primary' as varchar) as method
    from xml_xref_sequences
    where reftype = 'primaryRef'
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from tmp_ambiguous_references
            except all
            select source, filename, entry, interactorid
            from tmp_unambiguous_matching_references
            )
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- References without sequence database information.

-- create temporary table tmp_null_references as
--     select source, filename, entry, interactorid, count(distinct sequence) as sequences
--     from xml_xref_sequences
--     group by source, filename, entry, interactorid
--     having count(distinct refsequence) = 0;

-- Interactors whose only sequence information originates from the interaction
-- record.

create temporary table tmp_unambiguous_null_references as
    select source, filename, entry, interactorid, min(sequence) as sequence,
        min(taxid) as taxid, array[cast(null as varchar)] as sequencelinks,
        min(reftype) as reftype,
        cast('interaction' as varchar) as method
    from xml_xref_sequences
    where sequence is not null
        and refsequence is null
    group by source, filename, entry, interactorid
    having count(distinct sequence) = 1;

-- Combine the different interactors.

insert into irefindex_assignments
    select *
    from tmp_unambiguous_references
    union all
    select *
    from tmp_unambiguous_matching_references
    union all
    select *
    from tmp_unambiguous_primary_references
    union all
    select *
    from tmp_unambiguous_null_references;

commit;
