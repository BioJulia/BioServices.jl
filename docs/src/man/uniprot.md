```@meta
CurrentModule=BioServices.UniProt
```

# UniProt

[UniProt](https://www.uniprot.org) is a database of protein sequences and functional annotation.
`BioServices.UniProt` is an interface to the [UniProt REST API](https://www.uniprot.org/help/api) hosted at https://rest.uniprot.org.

## Getting Started

Import module:

```julia
using BioServices.Sessions, BioServices.UniProt, Downloads
s = Session(DownloadsClient(), UniProtAPI())
```

Every function returns a request, which the [session](sessions.md) runs: `run(s, uniprotentry("P08069"))` returns a `Response`, whose data `text(res)` reads.
The format of the data is set by the `format` query parameter, e.g. `"json"`, `"fasta"`, `"tsv"`, `"list"`, `"xml"`, or `"txt"`.
With `format="json"`, the body can be parsed with a JSON library such as [JSON.jl](https://github.com/JuliaIO/JSON.jl).

Other query parameters are passed as keyword arguments.
Parameters that accept comma-separated lists, such as `fields`, can also be given as vectors.

## Datasets

The `dataset` keyword selects which UniProt database to query.
The default is `"uniprotkb"`; others include `"uniref"`, `"uniparc"`, `"proteomes"`, `"genecentric"`, `"taxonomy"`, `"keywords"`, `"citations"`, `"diseases"`, `"database"`, `"locations"`, `"unirule"`, `"arba"`, and `"unisave"`.

## Examples

### Retrieve entries

```julia
julia> res = run(s, uniprotentry("P08069"; format="fasta"));

julia> print(text(res))
>sp|P08069|IGF1R_HUMAN Insulin-like growth factor 1 receptor OS=Homo sapiens OX=9606 GN=IGF1R PE=1 SV=1
MKSGSGGGSPTSLWGLLFLSAALSLWPTSGEICGPGIDIRNDYQQLKRLENCTVIEGYLH
...

julia> res = run(s, uniprotentries(["P08069", "P35626"]; format="fasta"));
```

### Search

The query syntax is described in the [UniProt help](https://www.uniprot.org/help/query-fields).
`fields` selects the [columns](https://www.uniprot.org/help/return_fields) returned in `tsv` format.

```julia
julia> res = run(s, uniprotsearch("id:T2R38_MOUSE"; fields="accession", format="tsv"));

julia> print(text(res))
Entry
Q7TQA6

julia> res = run(s, uniprotsearch("gene_exact:IGF1R AND reviewed:true"; fields=["accession", "organism_name"], format="tsv"));
```

Search results are paginated, with at most 500 results per page (set by `size`).
The total number of results is in the `X-Total-Results` header, and `uniprotnext` gives the request for the following page:

```julia
res = run(s, uniprotsearch("gene_exact:IGF1R"; format="list", size=100))
accessions = split(text(res))
while (next = uniprotnext(res)) !== nothing
    res = run(s, next)
    append!(accessions, split(text(res)))
end
```

Alternatively, `uniprotstream` returns all results in a single response.

### ID mapping

ID mapping converts identifiers between databases.
It runs as a job on the server: submit it, poll until it finishes, then retrieve the results.

```julia
julia> using JSON

julia> res = run(s, uniprotidmapping(["ENSMUSG00000067064", "ENSMUSG00000057464"]; from="Ensembl", to="UniProtKB"));

julia> jobid = JSON.parse(text(res))["jobId"];

julia> while haskey(JSON.parse(text(run(s, uniprotidmappingstatus(jobid)))), "jobStatus")   # the finished job's status redirects to its results
           sleep(1)
       end

julia> res = run(s, uniprotidmappingresults(jobid; dataset="uniprotkb", fields=["accession", "id"], format="tsv"));

julia> print(text(res))
From	Entry	Entry Name
ENSMUSG00000067064	Q8VGU4	Q8VGU4_MOUSE
ENSMUSG00000057464	A0A0N4SV77	A0A0N4SV77_MOUSE
ENSMUSG00000057464	Q7TQS4	Q7TQS4_MOUSE
```

A job that fails makes running `uniprotidmappingstatus` throw a `StatusError`.
`uniprotidmappingfields` lists the supported `from` and `to` databases.

### Identifiers

These functions parse UniProt identifiers locally, without contacting the service.
`uniprotaccession` extracts the [accession](https://www.uniprot.org/help/accession_numbers) from an accession with an isoform or version suffix, from the [entry name](https://www.uniprot.org/help/entry_name) of an unreviewed entry, or from a [FASTA header](https://www.uniprot.org/help/fasta-headers):

```julia
julia> uniprotaccession("Q8VGW6_MOUSE")
"Q8VGW6"

julia> isuniprotaccession("Q8VGW6")
true
```

The entry names of reviewed (Swiss-Prot) entries contain a mnemonic protein code instead of the accession:

```julia
julia> uniprotentryname("IGF1R_HUMAN")
(protein = "IGF1R", species = "HUMAN")

julia> res = run(s, uniprotsearch("id:IGF1R_HUMAN"; fields="accession", format="list"));

julia> text(res)
"P08069\n"
```

`uniprotfastaheader` splits a FASTA header into its fields:

```julia
julia> res = run(s, uniprotentry("P08069"; format="fasta"));

julia> uniprotfastaheader(first(eachline(IOBuffer(text(res)))))
(db = "sp", id = "P08069", entryname = "IGF1R_HUMAN", proteinname = "Insulin-like growth factor 1 receptor", organism = "Homo sapiens", taxid = 9606, gene = "IGF1R", existence = 1, version = 1)
```

## Methods

```@docs
uniprotentry
uniprotentries
uniprotsearch
uniprotstream
uniprotnext
uniprotidmapping
uniprotidmappingstatus
uniprotidmappingresults
uniprotidmappingdetails
uniprotidmappingfields
isuniprotaccession
uniprotaccession
uniprotentryname
uniprotfastaheader
```
