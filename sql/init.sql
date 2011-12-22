-- Utilities.

create aggregate array_accum (
    sfunc = array_append,
    basetype = anyelement,
    stype = anyarray,
    initcond = '{}'
);

create aggregate array_array_accum (
    sfunc = array_cat,
    basetype = anyarray,
    stype = anyarray,
    initcond = '{}'
);
