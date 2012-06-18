-- Show source information.

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

create temporary table tmp_manifest as
    select 'Source' as source, 'Release date' as releasedate,
        'Release URL' as releaseurl, 'Download files' as downloadfiles,
        'Version' as version
    union all (
        select source, to_char(releasedate, 'YYYY-MM-DD'),
            releaseurl, downloadfiles, version
        from irefindex_manifest
        order by source
    );

\copy tmp_manifest to '<directory>/irefindex_manifest_final'

rollback;
