-- Import PSI-MI XML data.

-- Copyright (C) 2011, 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
-- Original author: Paul Boddie <paul.boddie@biotek.uio.no>
--
-- This program is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.

begin;

-- NOTE: Tables based on the schema.

create temporary table tmp_experiments (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    experimentid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null -- integer for PSI MI XML 2.5
);

create temporary table tmp_interactors (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    interactorid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit interactor reference
    participantid varchar not null, -- integer for PSI MI XML 2.5
    interactionid varchar not null -- integer for PSI MI XML 2.5
);

create temporary table tmp_names (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    property varchar not null,
    nametype varchar not null,
    typelabel varchar,
    typecode varchar,
    name varchar -- some names can actually be unspecified
);

create temporary table tmp_xref (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    property varchar not null,
    reftype varchar not null,
    refvalue varchar, -- MIPS omits some refvalues
    dblabel varchar,
    dbcode varchar,
    reftypelabel varchar,
    reftypecode varchar
);

create temporary table tmp_organisms (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    taxid integer not null
);

create temporary table tmp_sequences (
    source varchar not null,
    filename varchar not null,
    entry integer not null,
    scope varchar not null,
    parentid varchar not null, -- integer for PSI MI XML 2.5
    refclass varchar not null, -- implicit or explicit reference
    actualsequence varchar not null, -- the original sequence
    sequence varchar not null  -- actually a signature/digest
);

\copy tmp_experiments from '<directory>/experiment.txt'
\copy tmp_interactors from '<directory>/interactor.txt'
\copy tmp_names from '<directory>/names.txt'
\copy tmp_xref from '<directory>/xref.txt'
\copy tmp_organisms from '<directory>/organisms.txt'
\copy tmp_sequences from '<directory>/sequences.txt'

-- De-duplicate experiment identifier usage (seen in OPHID).

insert into xml_experiments
    select distinct source, filename, entry, experimentid, interactionid
    from tmp_experiments;

-- Assume that interactor identifiers will use one refclass scheme or the other,
-- not both at the same time.

insert into xml_interactors
    select source, filename, entry, interactorid, participantid, interactionid
    from tmp_interactors;

-- Select names which use the active refclass scheme for interactors, plus all
-- other name definitions.

delete from tmp_names
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_names
    select source, filename, entry, scope, parentid, property, nametype, typelabel, typecode, name
    from tmp_names;

-- Select references which use the active refclass scheme for interactors, plus
-- all other reference definitions.

delete from tmp_xref
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_xref
    select source, filename, entry, scope, parentid, property, reftype, refvalue, dblabel, dbcode, reftypelabel, reftypecode
    from tmp_xref;

-- Select organism definitions which use the active refclass scheme for
-- interactors, plus all other organism definitions.

delete from tmp_organisms
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_organisms
    select source, filename, entry, scope, parentid, taxid
    from tmp_organisms;

-- Select sequence definitions which use the active refclass scheme for
-- interactors. There should be no other sequence definitions.

delete from tmp_sequences
where scope = 'interactor'
    and refclass not in (select distinct refclass from tmp_interactors);

insert into xml_sequences
    select source, filename, entry, scope, parentid, sequence
    from tmp_sequences;

insert into xml_sequences_original
    select distinct T.sequence, T.actualsequence
    from tmp_sequences as T
    left outer join xml_sequences_original as O
        on T.sequence = O.sequence
    where O.sequence is null;

commit;
