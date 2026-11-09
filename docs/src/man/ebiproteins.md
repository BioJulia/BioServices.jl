```@meta
CurrentModule=BioServices.EBIProteins
```

# EBIProteins

`BioServices.EBIProteins` is an interface to the
[EMBL-EBI Proteins API](https://www.ebi.ac.uk/proteins/api/doc/), which serves UniProt
entries together with variation, proteomics, antigen, and genomic coordinate data.
For searching UniProt and for ID mapping, see [UniProt](@ref).

## Getting Started

Import module:

```julia
using BioServices.EBIProteins
```

Every function returns an `HTTP.Response`. The format of the data is set by the
`contenttype` keyword, which is sent as the `Accept` header (e.g. `"application/json"`,
`"application/xml"`, `"text/x-fasta"`).

## Examples

Retrieve the sequences of two entries:

```julia
julia> res = ebiproteins(accession="P08069,P35626", size=2, contenttype="text/x-fasta");
```

Retrieve the transmembrane segments of an entry:

```julia
julia> res = ebifeatures(accession="P08069", types="TRANSMEM", contenttype="application/json");
```

## Methods

```@docs
ebiproteins
ebifeatures
ebivariation
ebiproteomics
ebiantigen
ebiproteomes
ebigenecentric
ebitaxonomy
ebicoordinates
ebiuniparc
```
