begin;

-- Ambiguous references.

create table irefindex_ambiguous_references as
    select source, filename, entry, interactorid
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) > 1;

-- References without sequence database information.

create table irefindex_null_references as
    select source, filename, entry, interactorid, count(distinct sequence) as sequences
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 0;

-- Unambiguous primary or secondary references.
-- The sequence chosen is the sequence database sequence.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('unambiguous' as varchar) as method
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Ambiguous references resolved by selecting records with identical interaction
-- and sequence database sequences, thus excluding the above completely
-- unambiguous references.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_matching_sequence_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('matching sequence' as varchar) as method
    from xml_xref_sequences
    where sequence = refsequence
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from irefindex_ambiguous_references
            )
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Ambiguous references resolved by selecting records with identical interaction
-- and sequence database taxonomy identifiers.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_matching_species_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('matching species' as varchar) as method
    from xml_xref_sequences
    where taxid = reftaxid
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from irefindex_ambiguous_references
            except all
            select source, filename, entry, interactorid
            from tmp_unambiguous_matching_sequence_references
            )
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Ambiguous references resolved by selecting records providing a valid primary
-- reference.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_primary_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence,
        min(reftaxid) as taxid, array_accum(sequencelink) as sequencelinks,
        min(reftype) as reftype,
        cast('primary' as varchar) as method
    from xml_xref_sequences
    where reftype = 'primaryRef'
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from irefindex_ambiguous_references
            except all (
                select source, filename, entry, interactorid
                from tmp_unambiguous_matching_sequence_references
                union all
                select source, filename, entry, interactorid
                from tmp_unambiguous_matching_species_references
                )
            )
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Interactors whose only sequence information originates from the interaction
-- record.
-- The reference type will be 'primaryRef' if present.

create temporary table tmp_unambiguous_null_references as
    select source, filename, entry, interactorid, min(sequence) as sequence,
        min(taxid) as taxid, array[cast(null as varchar)] as sequencelinks,
        min(reftype) as reftype,
        cast('interaction' as varchar) as method
    from xml_xref_sequences
    where sequence is not null
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from irefindex_null_references
            )
    group by source, filename, entry, interactorid
    having count(distinct sequence) = 1;

-- Combine the different interactors.

insert into irefindex_assignments
    select *
    from tmp_unambiguous_references
    union all
    select *
    from tmp_unambiguous_matching_sequence_references
    union all
    select *
    from tmp_unambiguous_matching_species_references
    union all
    select *
    from tmp_unambiguous_primary_references
    union all
    select *
    from tmp_unambiguous_null_references;

analyze irefindex_assignments;

-- Remaining unassigned interactors.

create table irefindex_unassigned as
    select source, filename, entry, interactorid,
        count(distinct sequence) as sequences, count(distinct refsequence) as refsequences
    from xml_xref_sequences
    where (source, filename, entry, interactorid) not in (
        select source, filename, entry, interactorid
        from irefindex_assignments
        )
    group by source, filename, entry, interactorid;

commit;
