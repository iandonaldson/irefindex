begin;

-- Unambiguous primary or secondary references.

create temporary table tmp_unambiguous_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence, min(reftaxid) as taxid
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Ambiguous references resolved by selecting records with identical interaction
-- and sequence database sequences, thus excluding the above completely
-- unambiguous references.

create temporary table tmp_ambiguous_references as
    select source, filename, entry, interactorid
    from xml_xref_sequences
    group by source, filename, entry, interactorid
    having count(distinct refsequence) > 1;

create temporary table tmp_unambiguous_matching_references as
    select source, filename, entry, interactorid, min(refsequence) as sequence, min(reftaxid) as taxid
    from xml_xref_sequences
    where sequence = refsequence
        and (source, filename, entry, interactorid) in (
            select source, filename, entry, interactorid
            from tmp_ambiguous_references
            )
    group by source, filename, entry, interactorid
    having count(distinct refsequence) = 1;

-- Interactors whose only sequence information originates from the interaction
-- record.

create temporary table tmp_unambiguous_null_references as
    select source, filename, entry, interactorid, min(sequence) as sequence, min(taxid) as taxid
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
    from tmp_unambiguous_null_references;

commit;
