begin;

-- Combine the interactor details with the identifier sequence details.

insert into xml_xref_interactor_sequences
    select source, filename, entry, interactorid, reftype, reftypelabel,
        I.dblabel, I.refvalue, I.originaldblabel, I.originalrefvalue, missing,
        taxid, sequence, sequencelink, reftaxid, refsequence
    from xml_xref_interactors as I
    left outer join xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue);

create index xml_xref_interactor_sequences_index on xml_xref_interactor_sequences(source, filename, entry, interactorid);
analyze xml_xref_interactor_sequences;

commit;
