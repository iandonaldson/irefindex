begin;

create temporary table tmp_unknown_gi as
    select distinct I.refvalue
    from xml_xref_interactors as I
    left outer join xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue)
    where S.refvalue is null
        and I.dblabel = 'genbank_protein_gi'
	and I.refvalue ~ '^[0-9]*$';

\copy tmp_unknown_gi to '<directory>/unknown_gi'

rollback;
