-- Show interactor origin information.

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

-- Show the number of distinct interactors by database origin.

create temporary table tmp_all_interactors_by_database as
    select dblabel, count(distinct refvalue) as total, reftype, isidentity
    from (
        select dblabel, refvalue, reftype, case
            when reftypelabel = 'identity' then true
            else false end as isidentity
        from xml_xref_all_interactors
        ) as X
    group by dblabel, reftype, isidentity
    order by dblabel, reftype, isidentity;

\copy tmp_all_interactors_by_database to '<directory>/all_interactors_by_database'

create temporary table tmp_interactors_by_database as
    select coalesce(notfound.dblabel, found.dblabel) as dblabel,
        coalesce(notfound.total, 0) as unmatched, coalesce(found.total, 0) as matched,
        round(
            cast(
                cast(coalesce(found.total, 0) as real) / (coalesce(notfound.total, 0) + coalesce(found.total, 0)) * 100
                as numeric
                ), 2
            ) as coverage
    from (
        select dblabel, count(distinct refvalue) as total
        from xml_xref_interactor_sequences
        where refsequence is null
        group by dblabel
        ) as notfound
    full outer join (
        select dblabel, count(distinct refvalue) as total
        from xml_xref_interactor_sequences
        where refsequence is not null
        group by dblabel
        ) as found
        on notfound.dblabel = found.dblabel
    order by coalesce(notfound.dblabel, found.dblabel);

\copy tmp_interactors_by_database to '<directory>/interactors_by_database'

rollback;
