begin;

-- Show the number of distinct interactors by connection to sequence database.

create temporary table tmp_interactors_by_sequencelink as
    select dblabel, sequencelink, count(distinct refvalue)
    from xml_xref_sequences
    group by dblabel, sequencelink
    order by dblabel, sequencelink;

\copy tmp_interactors_by_sequencelink to '<directory>/interactors_by_sequencelink'

rollback;
