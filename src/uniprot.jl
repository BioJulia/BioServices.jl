# UniProt
# ======
#
# APIs for the UniProt REST service (rest.uniprot.org)
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioServices.jl/blob/master/LICENSE.md

"""
UniProt module.

The `UniProt` module provides a programming interface to the UniProt REST API at https://rest.uniprot.org.
The following functions are exported from this module:
1. `uniprotentry`: retrieve a single entry by its identifier
2. `uniprotentries`: retrieve several entries by their identifiers
3. `uniprotsearch`: search a dataset (paginated)
4. `uniprotstream`: search a dataset (all results in one response)
5. `uniprotnext`: retrieve the next page of a paginated result
6. `uniprotidmapping`: submit an ID mapping job
7. `uniprotidmappingstatus`: check the status of an ID mapping job
8. `uniprotidmappingresults`: retrieve the results of an ID mapping job
9. `uniprotidmappingdetails`: retrieve the parameters of an ID mapping job
10. `uniprotidmappingfields`: list the databases supported by ID mapping

Each of these functions returns an `HTTP.Response`.
The response format is chosen with the `format` query parameter (e.g. "json", "fasta", "tsv", "list", "xml", "txt", "gff"); not every format is supported by every dataset.
Setting the query parameter `compressed=true` returns a gzip-compressed body.

The following functions parse UniProt identifiers without contacting the service:
1. `isuniprotaccession`: test whether a string is an accession
2. `uniprotaccession`: extract the accession from an identifier, entry name, or FASTA header
3. `uniprotentryname`: split an entry name into its protein and species codes
4. `uniprotfastaheader`: parse a UniProtKB FASTA header

See "UniProt website REST API" (https://www.uniprot.org/help/api) for more details.
"""
module UniProt

export
    uniprotentry,
    uniprotentries,
    uniprotsearch,
    uniprotstream,
    uniprotnext,
    uniprotidmapping,
    uniprotidmappingstatus,
    uniprotidmappingresults,
    uniprotidmappingdetails,
    uniprotidmappingfields,
    isuniprotaccession,
    uniprotaccession,
    uniprotentryname,
    uniprotfastaheader

import HTTP
import BioServices.request

const baseURL = "https://rest.uniprot.org/"

# rest.uniprot.org applies gzip twice when the client accepts gzip, leaving the body compressed after HTTP.jl decodes it.
# Compressed bodies can be requested explicitly with the `compressed=true` query parameter.
const headers = ["Accept-Encoding" => "identity"]

# Query parameter that `uniprotentries` uses to pass identifiers to each dataset
const batchkeys = Dict("uniprotkb" => "accessions", "uniparc" => "upis", "uniref" => "ids")

# The datasets that ID mapping results can be expressed in
const idmappingdatasets = ("uniprotkb", "uniparc", "uniref")


# Retrieval and search
# --------------------

"""
    uniprotentry(id; dataset="uniprotkb", subset=nothing, params...)

Retrieve a single entry from `dataset`.

Calls the endpoint "<dataset>/<id>", or "<dataset>/<id>/<subset>" if `subset` is set.

`dataset` may be "uniprotkb", "uniref", "uniparc", "proteomes", "genecentric", "taxonomy", "keywords", "citations", "diseases", "database", "locations", "unirule", "arba", or "unisave".

`subset` selects a sub-resource of the entry, e.g. "light" (uniref, uniparc), "members" (uniref), "databases" (uniparc), or "status" (unisave).

Query Parameters: format, fields, version (uniprotkb); see the UniProt API documentation for the parameters accepted by each dataset and subset.

# Examples

```julia
julia> res = uniprotentry("P08069"; format="fasta");

julia> res = uniprotentry("9606"; dataset="taxonomy", format="json");
```
"""
function uniprotentry(id; dataset = "uniprotkb", subset = nothing, params...)
    params = process_parameters(params)
    path = baseURL * HTTP.escapeuri(dataset) * "/" * HTTP.escapeuri(string(id))
    if !isnothing(subset)
        path *= "/" * HTTP.escapeuri(subset)
    end
    return request("GET", path, headers, query = params)
end

"""
    uniprotentries(ids; dataset="uniprotkb", params...)

Retrieve the entries listed in `ids` (a vector or a comma-separated string) from `dataset`, which must be "uniprotkb", "uniparc", or "uniref".

Results are paginated; see [`uniprotnext`](@ref).

Query Parameters: format, fields, size, sort, download

# Examples

```julia
julia> res = uniprotentries(["P08069", "P35626"]; format="fasta");
```
"""
function uniprotentries(ids; dataset = "uniprotkb", params...)
    haskey(batchkeys, dataset) ||
        throw(ArgumentError("`dataset` must be one of $(join(sort!(collect(keys(batchkeys))), ", ")); got \"$dataset\"."))
    params = process_parameters(params)
    params[Symbol(batchkeys[dataset])] = joinids(ids)
    path = baseURL * dataset * "/" * batchkeys[dataset]
    return request("GET", path, headers, query = params)
end

"""
    uniprotsearch(query; dataset="uniprotkb", params...)

Search `dataset` using the UniProt [query syntax](https://www.uniprot.org/help/query-fields), e.g. `"gene:IGF1R AND organism_id:9606"`.

Calls the endpoint "<dataset>/search".
Results are paginated: `size` (at most 500) sets the number of results per page, and [`uniprotnext`](@ref) retrieves the following page.
The total number of hits is in the "X-Total-Results" response header.
Use [`uniprotstream`](@ref) to retrieve all results at once.

Query Parameters: format, fields, size, sort, includeIsoform, cursor

# Examples

```julia
julia> res = uniprotsearch("id:T2R38_MOUSE"; fields="accession", format="tsv");

julia> print(String(res.body))
Entry
Q7TQA6
```
"""
function uniprotsearch(query; dataset = "uniprotkb", params...)
    params = process_parameters(params)
    params[:query] = string(query)
    return request("GET", baseURL * HTTP.escapeuri(dataset) * "/search", headers, query = params)
end

"""
    uniprotstream(query; dataset="uniprotkb", params...)

Search `dataset` and return all results in a single response.

Calls the endpoint "<dataset>/stream".
This is appropriate for queries with many results, but the request may take a long time to complete for very large result sets.
See [`uniprotsearch`](@ref) for the query syntax.

Query Parameters: format, fields, sort, includeIsoform, download
"""
function uniprotstream(query; dataset = "uniprotkb", params...)
    params = process_parameters(params)
    params[:query] = string(query)
    return request("GET", baseURL * HTTP.escapeuri(dataset) * "/stream", headers, query = params)
end

"""
    uniprotnext(res::HTTP.Response)

Retrieve the next page of a paginated result `res`, as returned by [`uniprotsearch`](@ref), [`uniprotentries`](@ref), or [`uniprotidmappingresults`](@ref).
Returns `nothing` if `res` is the last page.

# Examples

```julia
res = uniprotsearch("gene:IGF1R"; format="list", size=100)
while res !== nothing
    # process String(res.body)
    res = uniprotnext(res)
end
```
"""
function uniprotnext(res::HTTP.Response)
    link = HTTP.header(res, "Link")
    m = match(r"<([^>]*)>\s*;\s*rel=\"next\"", link)
    isnothing(m) && return nothing
    return request("GET", String(m.captures[1]), headers)
end


# ID mapping
# ----------

"""
    uniprotidmapping(ids; from="UniProtKB_AC-ID", to="UniProtKB", taxId=nothing)

Submit an ID mapping job converting `ids` (a vector or a comma-separated string) from the database `from` to the database `to`.
`taxId` restricts the mapping to a taxon, and is accepted only for some `from` databases.

The body of the response is JSON containing the `jobId`, which is passed to [`uniprotidmappingstatus`](@ref) and [`uniprotidmappingresults`](@ref).
The supported `from`/`to` pairs are listed by [`uniprotidmappingfields`](@ref).

# Examples

```julia
julia> res = uniprotidmapping(["ENSMUSG00000067064", "ENSMUSG00000057464"]; from="Ensembl");

julia> jobid = JSON.parse(String(res.body))["jobId"];
```
"""
function uniprotidmapping(ids; from = "UniProtKB_AC-ID", to = "UniProtKB", taxId = nothing)
    params = Dict{String, String}("ids" => joinids(ids), "from" => string(from), "to" => string(to))
    isnothing(taxId) || (params["taxId"] = string(taxId))
    header = [headers; "Content-Type" => "application/x-www-form-urlencoded"]
    return request(
        "POST", baseURL * "idmapping/run", header, body = HTTP.escapeuri(params),
        retry_non_idempotent = true
    )
end

"""
    uniprotidmappingstatus(jobid)

Check the status of the ID mapping job `jobid`.

While the job is in progress, the response status is 200 and its JSON body has a `jobStatus` field (e.g. "NEW", "RUNNING").
Once the job has finished, the response status is 303 (redirect to the results), and the results can be retrieved with [`uniprotidmappingresults`](@ref).

A job that failed raises an `HTTP.StatusError`; its body describes the error.
"""
function uniprotidmappingstatus(jobid)
    return request("GET", baseURL * "idmapping/status/" * HTTP.escapeuri(string(jobid)), headers, redirect = false)
end

"""
    uniprotidmappingresults(jobid; dataset=nothing, stream=false, params...)

Retrieve the results of the ID mapping job `jobid`.

When `dataset` is `nothing`, the results are pairs of `from` and `to` identifiers.
When `dataset` is "uniprotkb", "uniparc", or "uniref" (matching the `to` database of the job), the results include the full entries, which can be filtered with `query` and formatted with `format` and `fields`.

If `stream` is `false`, the results are paginated (see [`uniprotnext`](@ref)); otherwise they are returned in a single response.

Query Parameters: format, fields, query, size, sort, includeIsoform, download
"""
function uniprotidmappingresults(jobid; dataset = nothing, stream::Bool = false, params...)
    params = process_parameters(params)
    jobid = HTTP.escapeuri(string(jobid))
    path = baseURL * "idmapping/"
    if isnothing(dataset)
        path *= stream ? "stream/" * jobid : "results/" * jobid
    else
        dataset ∈ idmappingdatasets ||
            throw(ArgumentError("`dataset` must be `nothing` or one of $(join(idmappingdatasets, ", ")); got \"$dataset\"."))
        path *= dataset * (stream ? "/results/stream/" : "/results/") * jobid
    end
    return request("GET", path, headers, query = params)
end

"""
    uniprotidmappingdetails(jobid)

Retrieve the parameters (`from`, `to`, `ids`) of the ID mapping job `jobid`, together with a URL for its results.
"""
function uniprotidmappingdetails(jobid)
    return request("GET", baseURL * "idmapping/details/" * HTTP.escapeuri(string(jobid)), headers)
end

"""
    uniprotidmappingfields()

List the databases supported by ID mapping, and which can be used as `from` and `to` in [`uniprotidmapping`](@ref).
The body of the response is JSON.
"""
function uniprotidmappingfields()
    return request("GET", baseURL * "configure/idmapping/fields", headers)
end


# Identifiers
# -----------

# https://www.uniprot.org/help/accession_numbers
const accession_pattern = "[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9](?:[A-Z][A-Z0-9]{2}[0-9]){1,2}"
const rex_accession = Regex("^(?:$accession_pattern)\$")
# An accession at the start of a string, optionally preceded by a FASTA "sp|" or "tr|" prefix and followed by an isoform and/or version suffix, then by the end of the string, '_', '|', or whitespace
const rex_accession_prefix = Regex("^>?(?:(?:sp|tr)\\|)?($accession_pattern)(?:-\\d+)?(?:\\.\\d+)?(?:\$|[_|\\s])")
# https://www.uniprot.org/help/entry_name
const rex_entryname = Regex("^([A-Z0-9]{1,5}|$accession_pattern)_([A-Z0-9]{1,5})\$")
# https://www.uniprot.org/help/fasta-headers
const rex_fastaheader = r"^>?(sp|tr)\|(\S+?)\|(\S+) (.*?) OS=(.*?) OX=(\d+)(?: GN=(.*?))?(?: PE=(\d))?(?: SV=(\d+))?$"

"""
    isuniprotaccession(s)

Return `true` if `s` is a UniProtKB [accession](https://www.uniprot.org/help/accession_numbers), e.g. "P08069" or "A0A023GPI8".
Isoform ("P05067-2") and versioned ("P05067.3") identifiers return `false`; use [`uniprotaccession`](@ref) to extract the accession from them.
"""
isuniprotaccession(s::AbstractString) = occursin(rex_accession, s)

"""
    uniprotaccession(s)

Extract the UniProtKB accession at the start of `s`.
`s` may be
- an accession, optionally with an isoform or version suffix ("P05067-2", "Q8VGW6.37");
- an [entry name](https://www.uniprot.org/help/entry_name) of an unreviewed (TrEMBL) entry, e.g. "Q8VGW6_MOUSE";
- a UniProtKB [FASTA header](https://www.uniprot.org/help/fasta-headers), e.g. ">sp|P08069|IGF1R_HUMAN Insulin-like growth factor 1 receptor OS=...";
- any of the above followed by '_', '|', or whitespace and other text.

Isoform and version suffixes are removed.
Throws an `ArgumentError` if `s` does not start with an accession.
In particular, the entry name of a reviewed (Swiss-Prot) entry, such as "IGF1R_HUMAN", does not contain the accession; [`uniprotsearch`](@ref) can find it.

# Examples

```jldoctest; setup = :(using BioServices.UniProt)
julia> uniprotaccession("Q8VGW6_MOUSE")
"Q8VGW6"

julia> uniprotaccession("sp|P05067-2|A4_HUMAN Isoform APP305 of Amyloid-beta precursor protein OS=Homo sapiens OX=9606 GN=APP")
"P05067"
```
"""
function uniprotaccession(s::AbstractString)
    m = match(rex_accession_prefix, s)
    if isnothing(m)
        msg = "no UniProt accession found at the start of \"$s\""
        if occursin(rex_entryname, s)
            msg *= "; the entry names of reviewed entries contain no accession, use `uniprotsearch(\"id:$s\")` to look it up"
        end
        throw(ArgumentError(msg))
    end
    return String(m.captures[1])
end

"""
    uniprotentryname(s)

Split the UniProtKB [entry name](https://www.uniprot.org/help/entry_name) `s`, of the form "X_Y", into a named tuple `(; protein = X, species = Y)`.
For reviewed (Swiss-Prot) entries, `X` is a mnemonic protein code of at most 5 characters; for unreviewed (TrEMBL) entries, it is the accession.
`Y` is the mnemonic species code.

Throws an `ArgumentError` if `s` is not an entry name.
To obtain the entry name from a FASTA header, use [`uniprotfastaheader`](@ref).

# Examples

```jldoctest; setup = :(using BioServices.UniProt)
julia> uniprotentryname("IGF1R_HUMAN")
(protein = "IGF1R", species = "HUMAN")
```
"""
function uniprotentryname(s::AbstractString)
    m = match(rex_entryname, s)
    isnothing(m) && throw(ArgumentError("\"$s\" is not a UniProt entry name (X_Y)"))
    return (; protein = String(m.captures[1]), species = String(m.captures[2]))
end

"""
    uniprotfastaheader(s)

Parse the header line `s` of a UniProtKB [FASTA record](https://www.uniprot.org/help/fasta-headers), with or without the leading '>'.
Returns a named tuple with fields
- `db`: "sp" (reviewed, Swiss-Prot) or "tr" (unreviewed, TrEMBL)
- `id`: the accession, or the isoform identifier (e.g. "P05067-2") for an isoform
- `entryname`: the entry name, see [`uniprotentryname`](@ref)
- `proteinname`: the recommended protein name
- `organism`: the scientific name of the organism (`OS`)
- `taxid`: the NCBI taxonomy identifier of the organism (`OX`), an `Int`
- `gene`: the gene name (`GN`), or `nothing`
- `existence`: the protein existence level (`PE`), an `Int` from 1 to 5, or `nothing`
- `version`: the sequence version (`SV`), an `Int`, or `nothing`

`GN` is absent when the entry has no gene name; `PE` and `SV` are absent for isoforms.
Throws an `ArgumentError` if `s` is not a UniProtKB FASTA header.

# Examples

```jldoctest; setup = :(using BioServices.UniProt)
julia> uniprotfastaheader(">sp|P08069|IGF1R_HUMAN Insulin-like growth factor 1 receptor OS=Homo sapiens OX=9606 GN=IGF1R PE=1 SV=1")
(db = "sp", id = "P08069", entryname = "IGF1R_HUMAN", proteinname = "Insulin-like growth factor 1 receptor", organism = "Homo sapiens", taxid = 9606, gene = "IGF1R", existence = 1, version = 1)
```
"""
function uniprotfastaheader(s::AbstractString)
    m = match(rex_fastaheader, s)
    isnothing(m) && throw(ArgumentError("\"$s\" is not a UniProtKB FASTA header"))
    db, id, entryname, proteinname, organism, taxid, gene, existence, version = m.captures
    return (;
        db = String(db), id = String(id), entryname = String(entryname),
        proteinname = String(proteinname), organism = String(organism),
        taxid = parse(Int, taxid),
        gene = isnothing(gene) ? nothing : String(gene),
        existence = isnothing(existence) ? nothing : parse(Int, existence),
        version = isnothing(version) ? nothing : parse(Int, version),
    )
end


# Utilities
# ---------

joinids(ids::AbstractString) = String(ids)
joinids(ids) = join(ids, ',')

# Stringify query parameters; vectors (e.g. `fields=["accession", "length"]`) are comma-separated.
function process_parameters(params)
    return Dict{Symbol, String}(key => val isa AbstractVector ? join(val, ',') : string(val) for (key, val) in params)
end

end
