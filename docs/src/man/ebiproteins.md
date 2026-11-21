```@meta
CurrentModule=BioServices.EBIProteins
```

# EBIProteins

`BioServices.EBIProteins` is an interface to the [EMBL-EBI Proteins API](https://www.ebi.ac.uk/proteins/api/doc/), which serves UniProt entries together with variation, proteomics, antigen, and genomic coordinate data.
For searching UniProt and for ID mapping, see [UniProt](@ref).

## Getting Started

Import module:

```julia
using BioServices.Sessions, BioServices.EBIProteins, Downloads
s = Session(DownloadsClient(), EBIProteinsAPI())
```

Every function returns a request, which the [session](sessions.md) runs: `run(s, ebiproteins(accession="P08069"))` returns a `Response`.
The format of the data is set by the `contenttype` keyword, which is sent as the `Accept` header (e.g. `"application/json"`, `"application/xml"`, `"text/x-fasta"`).

## Examples

Retrieve the sequences of two entries:

```julia
julia> res = run(s, ebiproteins(accession="P08069,P35626", size=2, contenttype="text/x-fasta"));
```

Retrieve the transmembrane segments of an entry:

```julia
julia> res = run(s, ebifeatures(accession="P08069", types="TRANSMEM", contenttype="application/json"));
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
