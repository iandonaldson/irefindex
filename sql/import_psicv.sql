begin;

create temporary table tmp_psicv_terms (
    code varchar not null,
    name varchar not null
);

\copy tmp_psicv_terms from '<directory>/terms'

insert into psicv_terms select distinct code, name from tmp_psicv_terms;
analyze psicv_terms;

commit;