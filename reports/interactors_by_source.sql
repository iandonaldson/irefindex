-- Show interactor information for each data source.

-- Copyright (C) 2011, 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

-- Show the number of distinct identifiers by database.

create temporary table tmp_identifiers_by_database as
    select dblabel, count(distinct refvalue) as total, havesequence
    from (
        select dblabel, refvalue, refsequence is not null as havesequence
        from xml_xref_interactor_sequences
        ) as X
    group by dblabel, havesequence
    order by dblabel, havesequence;

\copy tmp_identifiers_by_database to '<directory>/identifiers_by_database'

-- Show the number of distinct interactors by data source.

create temporary table tmp_interactors_by_source_and_sequence as
    select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total, havesequence
    from (
        select source, filename, entry, interactorid, sequences <> 0 as havesequence
        from (
            select source, filename, entry, interactorid, count(distinct refsequence) as sequences
            from xml_xref_interactor_sequences
            group by source, filename, entry, interactorid
            ) as X
        ) as Y
    group by source, havesequence
    order by source, havesequence;

-- The output table has the following form:
--
-- <source> <total interactors> <total usable interactors> <total with sequence> <total without sequence>

create temporary table tmp_interactors_by_source as
    select X.source, X.total as full_total,
        coalesce(with_sequence.total, 0) + coalesce(without_sequence.total, 0) as total,
        coalesce(with_sequence.total, 0) as total_with_sequence,
        coalesce(without_sequence.total, 0) as total_without_sequence
    from (
        select source, count(distinct array[filename, cast(entry as varchar), interactorid]) as total
        from xml_xref_all_interactors
        group by source
        ) as X
    left outer join (
        select source, total
        from tmp_interactors_by_source_and_sequence
        where havesequence
        ) as with_sequence
        on X.source = with_sequence.source
    left outer join (
        select source, total
        from tmp_interactors_by_source_and_sequence
        where not havesequence
        ) as without_sequence
        on X.source = without_sequence.source
    order by X.source;

\copy tmp_interactors_by_source to '<directory>/interactors_by_source'

rollback;
