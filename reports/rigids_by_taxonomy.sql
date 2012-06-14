-- Show RIG identifier (and thus interaction) details for each organism.

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

-- Show rigids grouped by the original taxonomy identifier.

create temporary table tmp_rigids_by_originaltaxid as
    select A.originaltaxid, name, count(distinct rigid) as rigids
    from irefindex_interactions as R
    inner join irefindex_assignments as A
        on (R.source, R.filename, R.entry, R.interactorid) =
           (A.source, A.filename, A.entry, A.interactorid)
    inner join taxonomy_names as N
        on A.originaltaxid = N.taxid
        and nameclass = 'scientific name'
    group by A.originaltaxid, name
    order by count(distinct rigid) desc;

\copy tmp_rigids_by_originaltaxid to '<directory>/rigids_by_originaltaxid'

-- Show the top 15 organisms in a form viewable using...
--
-- column -t -s $'\t' rigids_by_originaltaxid_top

create temporary table tmp_rigids_by_originaltaxid_top as
    select 'NCBI taxonomy identifier' as organism, 'Scientific name' as name, 'Number of interactions' as interactions
    union all
    select cast(originaltaxid as varchar), name, cast(rigids as varchar)
    from tmp_rigids_by_originaltaxid
    limit 15;

\copy tmp_rigids_by_originaltaxid_top to '<directory>/rigids_by_originaltaxid_top'

-- Show rigids grouped by the selected taxonomy identifier.

create temporary table tmp_rigids_by_taxid as
    select A.taxid, name, count(distinct rigid) as rigids
    from irefindex_interactions as R
    inner join irefindex_assignments as A
        on (R.source, R.filename, R.entry, R.interactorid) =
           (A.source, A.filename, A.entry, A.interactorid)
    inner join taxonomy_names as N
        on A.taxid = N.taxid
        and nameclass = 'scientific name'
    group by A.taxid, name
    order by count(distinct rigid) desc;

\copy tmp_rigids_by_taxid to '<directory>/rigids_by_taxid'

-- Show the top 15 organisms in a form viewable using...
--
-- column -t -s $'\t' rigids_by_taxid_top

create temporary table tmp_rigids_by_taxid_top as
    select 'NCBI taxonomy identifier' as organism, 'Scientific name' as name, 'Number of interactions' as interactions
    union all
    select cast(taxid as varchar), name, cast(rigids as varchar)
    from tmp_rigids_by_taxid
    limit 15;

\copy tmp_rigids_by_taxid_top to '<directory>/rigids_by_taxid_top'

rollback;
