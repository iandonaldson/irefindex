-- A simple schema purely for completing interactor data.

-- Copyright (C) 2011, 2012, 2013 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

create table refseq_proteins (
    accession varchar,
    version varchar,
    vnumber integer,
    gi integer not null,
    taxid integer,
    "sequence" varchar not null,
    length integer not null,
    missing boolean not null default false, -- indicates whether the protein was initially missing
    primary key(gi)
);

create table refseq_sequences (
    "sequence" varchar not null,            -- the digest representing the sequence
    actualsequence varchar not null,        -- the original sequence
    primary key("sequence")
);

create table refseq_identifiers (
    accession varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null,
    missing boolean not null default false, -- indicates whether the identifier was initially missing
    primary key(accession, dblabel, refvalue)
);
