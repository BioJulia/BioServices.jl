# EUtils
# ======
#
# APIs for E-Utilities.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioServices.jl/blob/master/LICENSE.md

"""
Entrez Programming Utilities (or E-Utilities) module.

The `EUtils` module provides a programming interface to the Entrez databases at NCBI.
Nine functions are exported from this module:
1. `einfo`: database statistics
2. `esearch`: text search
3. `epost`: UID upload
4. `esummary`: document summary download
5. `efetch`: data record download
6. `elink`: Entrez link
7. `egquery`: global query
8. `espell`: spelling suggestion
9. `ecitmatch`: batch citation searching in PubMed

See "Entrez Programming Utilities Help" (https://www.ncbi.nlm.nih.gov/books/NBK25501/) for more details.
Especially, ["E-utilities Quick Start"](https://www.ncbi.nlm.nih.gov/books/NBK25500/) is a good starting point and ["A General Introduction to the E-utilities"](https://www.ncbi.nlm.nih.gov/books/NBK25497/) will serve useful information about its concepts and functions.
The implemented APIs are based on the manual on January 23, 2015.

Each function returns a request, which a session runs:

    using BioServices.Sessions, BioServices.EUtils, Downloads
    s = Session(DownloadsClient(), EUtilsAPI())
    res = run(s, einfo(db = "pubmed"))

Searches that use the History server pass their `WebEnv` and `query_key` on through a context: `context(ctx, res)` returns `ctx` with those of response `res`.

The session's `EUtilsAPI` holds the NCBI API key, if any, and adds it to every request: `Session(DownloadsClient(), EUtilsAPI(api_key = ENV["NCBI_API_KEY"]))`, or `configure(s, EUtilsAPI(api_key = ...))`.
"""
module EUtils

export
    einfo,
    esearch,
    epost,
    esummary,
    efetch,
    elink,
    egquery,
    espell,
    ecitmatch,
    context,
    set_context!

import XMLDict
import JSON
using ..Sessions: Request, Response, EUtilsAPI, form, header, text

const baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"


# APIs of E-utilities
# -------------------

"""
    einfo(ctx=Dict(); params...)

Retrieve a list of databases or statistics for a database.

Parameters: db, version, retmode.
"""
einfo(ctx::AbstractDict = empty_context(); params...) = query_request("einfo.fcgi", params, ctx)

"""
    esearch(ctx=Dict(); params...)

Retrieve a list of UIDs matching a text query.

Parameters: db, term, usehistory, WebEnv, query_key, retstart, retmax, rettype, retmode, sort, field, datetype, reldate, mindate, maxdate.

With `usehistory = true`, pass the response to [`context`](@ref) to keep its `WebEnv` and `query_key`.
"""
esearch(ctx::AbstractDict = empty_context(); params...) = query_request("esearch.fcgi", params, ctx)

"""
    epost(ctx=Dict(); params...)

Upload or append a list of UIDs to the Entrez History server.

Parameters: db, id, WebEnv.

Pass the response to [`context`](@ref) to keep its `WebEnv` and `query_key`.
"""
epost(ctx::AbstractDict = empty_context(); params...) = form_request("epost.fcgi", params, ctx)

"""
    esummary(ctx=Dict(); params...)

Retrieve document summaries for a list of UIDs.

Parameters: db, id, query_key, WebEnv, retstart, retmax, retmode, version.
"""
esummary(ctx::AbstractDict = empty_context(); params...) = form_request("esummary.fcgi", params, ctx)

"""
    efetch(ctx=Dict(); params...)

Retrieve formatted data records for a list of UIDs.

Parameters: db, id, query_key, WebEnv, retmode, rettype, retstart, retmax, strand, seq_start, seq_stop, complexity.
"""
efetch(ctx::AbstractDict = empty_context(); params...) = form_request("efetch.fcgi", params, ctx)

"""
    elink(ctx=Dict(); params...)

Retrieve UIDs linked to an input set of UIDs.

Parameters: db, dbfrom, cmd, id, query_key, WebEnv, linkname, term, holding, datetype, reldate, mindate, maxdate.
"""
elink(ctx::AbstractDict = empty_context(); params...) = form_request("elink.fcgi", params, ctx)

"""
    egquery(ctx=Dict(); params...)

Retrieve the number of available records in all databases by a text query.

Parameters: term.
"""
egquery(ctx::AbstractDict = empty_context(); params...) = query_request("egquery.fcgi", params, ctx)

"""
    espell(ctx=Dict(); params...)

Retrieve spelling suggestions.

Parameters: db, term.
"""
espell(ctx::AbstractDict = empty_context(); params...) = query_request("espell.fcgi", params, ctx)

"""
    ecitmatch(ctx=Dict(); params...)

Retrieve PubMed IDs that correspond to a set of input citation strings.

Parameters: db, rettype, bdata.
"""
ecitmatch(ctx::AbstractDict = empty_context(); params...) = query_request("ecitmatch.cgi", params, ctx)

# Requests to an E-utility, with the context merged into the parameters.
query_request(utility, params, ctx) = Request{EUtilsAPI}("GET", string(baseURL, utility); query = parameters(params, ctx))
form_request(utility, params, ctx) = Request{EUtilsAPI}(
    "POST", string(baseURL, utility);
    headers = ["Content-Type" => "application/x-www-form-urlencoded"], body = form(parameters(params, ctx))
)

# Create an empty context.
empty_context() = Dict{Symbol, Any}()

"""
    context(ctx, res)

Return `ctx` with the `WebEnv` and `query_key` of the History server from response `res`, from `esearch` with `usehistory = true` or from `epost`.
A response without them, or with a failed status, leaves `ctx` as it is.
"""
context(ctx::AbstractDict, res::Response) = merge(Dict{Symbol, Any}(ctx), history(res.status, mediatype(header(res, "Content-Type")), res))

history(status, mediatype, res) = status == 200 ? history(mediatype, text(res)) : Dict{Symbol, Any}()
history(::Val{:xml}, data) = (doc = XMLDict.parse_xml(data); Dict{Symbol, Any}(:WebEnv => doc["WebEnv"], :query_key => doc["QueryKey"]))
history(::Val{:json}, data) = (r = JSON.parse(data)["esearchresult"]; Dict{Symbol, Any}(:WebEnv => r["webenv"], :query_key => r["querykey"]))
history(::Val, data) = Dict{Symbol, Any}()

mediatype(contenttype) = startswith(contenttype, "text/xml") ? Val(:xml) : startswith(contenttype, "application/json") ? Val(:json) : Val(:other)

"""
    set_context!(ctx, res)

Set the `WebEnv` and `query_key` from response `res` in `ctx`, as [`context`](@ref) returns them.
"""
set_context!(ctx, res) = merge!(ctx, context(ctx, res))

# The query parameters: the context and `params` merged, with IDs joined by commas, `usehistory` as "y" or left out, and every value a string.
parameters(params, ctx) = Dict(filter(p -> last(p) !== nothing, map(p -> first(p) => value(Val(first(p)), last(p)), collect(merge(Dict{Symbol, Any}(ctx), Dict{Symbol, Any}(params))))))

value(::Val{:id}, ids::AbstractString) = ids
value(::Val{:id}, ids) = join(map(string, ids), ',')
value(::Val{:usehistory}, use::Bool) = use ? "y" : nothing
value(_, x) = string(x)

end
