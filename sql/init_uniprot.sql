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

-- Accessions in the proteins table are primary accessions from the main
-- UniProt data files and isoforms from the FASTA files.

create table uniprot_proteins (
    uniprotid varchar not null,
    accession varchar not null,
    sequencedate varchar,           -- not supplied by FASTA
    taxid integer,                  -- not supplied by FASTA
    mw integer,                     -- not supplied by FASTA
    "sequence" varchar not null,
    length integer not null,
    source varchar not null,        -- indicates Swiss-Prot or TrEMBL origin
    primary key(accession)
);

create table uniprot_sequences (
    "sequence" varchar not null,        -- the digest representing the sequence
    actualsequence varchar not null,    -- the original sequence
    primary key("sequence")
);

create table uniprot_accessions (
    uniprotid varchar not null,
    accession varchar not null,
    primary key(uniprotid, accession)
);

create table uniprot_identifiers (
    uniprotid varchar not null,
    dblabel varchar not null,
    refvalue varchar not null,
    position integer not null,
    primary key(uniprotid, dblabel, refvalue)
);

create table uniprot_gene_names (
    uniprotid varchar not null,
    genename varchar not null,
    position integer not null,
    primary key(uniprotid, genename)
);

create table uniprot_isoforms (
    uniprotid varchar not null,
    isoform varchar not null,
    parent varchar not null,
    primary key(isoform)
);
