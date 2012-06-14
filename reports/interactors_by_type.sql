-- Show the nature of interactors.

-- Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create temporary table tmp_interactors_by_type as
    select I.source, X.refvalue, min(name), count(distinct array[I.source, I.filename, cast(I.entry as varchar), I.interactorid]) as total
    from xml_xref_interactors as I
    left outer join xml_xref_interactor_types as X
        on (I.source, I.filename, I.entry, I.interactorid) = (X.source, X.filename, X.entry, X.interactorid)
    left outer join psicv_terms as T
        on X.refvalue = T.code
    group by I.source, X.refvalue
    order by I.source, X.refvalue;

\copy tmp_interactors_by_type to '<directory>/interactors_by_type'

rollback;
