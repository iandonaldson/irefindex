-- Collect participant-related information.

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

insert into xml_xref_participants
    select source, filename, entry, parentid as participantid, property,

        -- Fix certain psi-mi references.

        case when dblabel = 'MI' and not refvalue like 'MI:%' then 'MI:' || refvalue
             else refvalue
        end as refvalue

    from xml_xref
    where scope = 'participant'
        and property in ('participantIdentificationMethod', 'biologicalRole', 'experimentalRole')
        and dblabel in ('MI', 'psimi', 'PSI-MI', 'psi-mi');

create index xml_xref_participants_index on xml_xref_participants (source, filename, entry, participantid);

analyze xml_xref_participants;

commit;
