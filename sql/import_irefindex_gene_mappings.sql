-- Create a mapping of gene names to UniProt and RefSeq proteins.
-- This is useful for mapping interactors and for canonicalisation.

-- Copyright (C) 2011, 2012 Ian Donaldson <ian.donaldson@biotek.uio.no>
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

-- Find gene identifier cross-references.

insert into irefindex_gene2uniprot
    select geneid, P.accession, P.sequencedate, P.taxid, P.sequence, P.length,
        P.source
    from gene_info as G
    inner join uniprot_identifiers as I
        on G.geneid = cast(I.refvalue as integer)
        and I.dblabel = 'GeneID'
    inner join uniprot_proteins as P
        on I.uniprotid = P.uniprotid;
        -- P.taxid = G.taxid could be used to override any gene association in the UniProt record

analyze irefindex_gene2uniprot;

-- NOTE: The uniprot_gene_names table was previously used to provide a
-- NOTE: correspondence between proteins and genes, but this was found to make
-- NOTE: canonical groups significantly different from previous releases.

insert into irefindex_gene2refseq
    select geneid, P.accession, P.taxid, P.sequence, P.length
    from gene2refseq as G
    inner join refseq_proteins as P
        on G.accession = P.version;

analyze irefindex_gene2refseq;

-- NOTE: The gene_history table was previously used to provide a correspondence
-- NOTE: between proteins and genes, but this is likely to introduce unhelpful
-- NOTE: mappings to other parts of the processing pipeline and in output data.

commit;
