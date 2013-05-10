-- Import sequences from a previous release of iRefIndex.

-- Copyright (C) 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
-- Copyright (C) 2013 Paul Boddie <paul@boddie.org.uk>
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

-- Add archived sequences from the previous release that do not conflict with
-- those from active data.

create temporary table tmp_sequences_archived as
    select A.dblabel, A.refvalue, A.reftaxid, A.refsequence
    from irefindex_sequences_archived as A
    left outer join irefindex_sequences as S
        on (A.dblabel, A.refvalue) = (S.dblabel, S.refvalue)
    where S.refvalue is null
    union all
    select dblabel, refvalue, reftaxid, refsequence
    from irefindex_sequences
    where reftaxid is not null;

\copy tmp_sequences_archived to '<directory>/sequences_archived'

rollback;
