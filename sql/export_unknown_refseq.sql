begin;

create temporary table tmp_unknown_refseq as
    select distinct I.refvalue
    from xml_xref_interactors as I
    left outer join xml_xref_sequences as S
        on (I.dblabel, I.refvalue) = (S.dblabel, S.refvalue)
    where S.refvalue is null
        and I.dblabel = 'refseq'
	and I.refvalue ~ '^[A-Z]P_[0-9]*([.][0-9]*)?$';

\copy tmp_unknown_refseq to '<directory>/unknown_refseq'

rollback;
