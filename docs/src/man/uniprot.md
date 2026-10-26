```@meta
CurrentModule=BioServices.UniProt
```

# UniProt

[UniProt](https://www.uniprot.org) is a database of protein sequences and functional annotation.
`BioServices.UniProt` is an interface to the [UniProt REST API](https://www.uniprot.org/help/api) hosted at https://rest.uniprot.org.

## Getting Started

Import module:

```julia
using BioServices.UniProt
```

Every function returns an `HTTP.Response`; the data is in `res.body`.
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
julia> res = uniprotentry("P08069"; format="fasta");

julia> print(String(res.body))
>sp|P08069|IGF1R_HUMAN Insulin-like growth factor 1 receptor OS=Homo sapiens OX=9606 GN=IGF1R PE=1 SV=1
MKSGSGGGSPTSLWGLLFLSAALSLWPTSGEICGPGIDIRNDYQQLKRLENCTVIEGYLH
...

julia> res = uniprotentries(["P08069", "P35626"]; format="fasta");
```

### Search

The query syntax is described in the [UniProt help](https://www.uniprot.org/help/query-fields).
`fields` selects the [columns](https://www.uniprot.org/help/return_fields) returned in `tsv` format.

```julia
julia> res = uniprotsearch("id:T2R38_MOUSE"; fields="accession", format="tsv");

julia> print(String(res.body))
Entry
Q7TQA6

julia> res = uniprotsearch("gene_exact:IGF1R AND reviewed:true"; fields=["accession", "organism_name"], format="tsv");
```

Search results are paginated, with at most 500 results per page (set by `size`).
The total number of results is in the `X-Total-Results` header, and `uniprotnext` retrieves the following page:

```julia
res = uniprotsearch("gene_exact:IGF1R"; format="list", size=100)
accessions = String[]
while res !== nothing
    append!(accessions, split(String(res.body)))
    res = uniprotnext(res)
end
```

Alternatively, `uniprotstream` returns all results in a single response.

### ID mapping

ID mapping converts identifiers between databases. It runs as a job on the server: submit it, poll until it finishes, then retrieve the results.

```julia
julia> using JSON

julia> res = uniprotidmapping(["ENSMUSG00000067064", "ENSMUSG00000057464"]; from="Ensembl", to="UniProtKB");

julia> jobid = JSON.parse(String(res.body))["jobId"];

julia> while uniprotidmappingstatus(jobid).status != 303   # 303 indicates that the job has finished
           sleep(1)
       end

julia> res = uniprotidmappingresults(jobid; dataset="uniprotkb", fields=["accession", "id"], format="tsv");

julia> print(String(res.body))
From	Entry	Entry Name
ENSMUSG00000067064	Q8VGU4	Q8VGU4_MOUSE
ENSMUSG00000057464	A0A0N4SV77	A0A0N4SV77_MOUSE
ENSMUSG00000057464	Q7TQS4	Q7TQS4_MOUSE
```

A job that fails makes `uniprotidmappingstatus` throw an `HTTP.StatusError`.
`uniprotidmappingfields` lists the supported `from` and `to` databases.

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
```
