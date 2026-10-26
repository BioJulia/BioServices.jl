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

Each function returns an `HTTP.Response`.
The response format is chosen with the `format` query parameter (e.g. "json", "fasta", "tsv", "list", "xml", "txt", "gff"); not every format is supported by every dataset.
Setting the query parameter `compressed=true` returns a gzip-compressed body.

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
    uniprotidmappingfields

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


# Utilities
# ---------

joinids(ids::AbstractString) = String(ids)
joinids(ids) = join(ids, ',')

# Stringify query parameters; vectors (e.g. `fields=["accession", "length"]`) are comma-separated.
function process_parameters(params)
    return Dict{Symbol, String}(key => val isa AbstractVector ? join(val, ',') : string(val) for (key, val) in params)
end

end
