# EUtils
# ======
#
# APIs for E-Utilities.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
Entrez Programming Utilities (or E-Utilities) module.

The `EUtils` module provides a programming interface to the Entrez databases at
NCBI. Nine functions are exported from this module:
1. `einfo`: database statistics
2. `esearch`: text search
3. `epost`: UID upload
4. `esummary`: document summary download
5. `efetch`: data record download
6. `elink`: Entrez link
7. `egquery`: global query
8. `espell`: spelling suggestion
9. `ecitmatch`: batch citation searching in PubMed

See "Entrez Programming Utilities Help"
(https://www.ncbi.nlm.nih.gov/books/NBK25501/) for more details. Especially,
["E-utilities Quick Start"](https://www.ncbi.nlm.nih.gov/books/NBK25500/) is a
good starting point and ["A General Introduction to the
E-utilities"](https://www.ncbi.nlm.nih.gov/books/NBK25497/) will serve useful
information about its concepts and functions. The implemented APIs are based on
the manual on January 23, 2015.
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
    set_context!

import XMLDict
import JSON
import HTTP

const baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"


# APIs of E-utilities
# -------------------

"""
    einfo(ctx=Dict(); params...)

Retrieve a list of databases or statistics for a database.

Parameters: db, version, retmode.
"""
function einfo(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    return request("GET", string(baseURL, "einfo.fcgi"), query=params)
end

"""
    esearch(ctx=Dict(); params...)

Retrieve a list of UIDs matching a text query.

Parameters: db, term, usehistory, WebEnv, query_key, retstart, retmax, rettype,
retmode, sort, field, datetype, reldate, mindate, maxdate.
"""
function esearch(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    res = request("GET", string(baseURL, "esearch.fcgi"), query=params, retry_non_idempotent=true)
    if get(params, :usehistory, "") == "y"
        set_context!(ctx, res)
    end
    return res
end

"""
    epost(ctx=Dict(); params...)

Upload or append a list of UIDs to the Entrez History server.

Parameters: db, id, WebEnv.
"""
function epost(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    body = HTTP.escapeuri(params)
    # added user-agent header as workaround for EOFError - HTTP.jl issue #342
    # headers = Dict("user-agent"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36")
    res = request("POST", string(baseURL, "epost.fcgi"), body=body, retry_non_idempotent=true)
    set_context!(ctx, res)
    return res
end

"""
    esummary(ctx=Dict(); params...)

Retrieve document summaries for a list of UIDs.

Parameters: db, id, query_key, WebEnv, retstart, retmax, retmode, version.
"""
function esummary(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    body = HTTP.escapeuri(params)
    return request("POST", string(baseURL, "esummary.fcgi"), body=body, retry_non_idempotent=true)
end

"""
    efetch(ctx=Dict(); params...)

Retrieve formatted data records for a list of UIDs.

Parameters: db, id, query_key, WebEnv, retmode, rettype, retstart, retmax,
strand, seq_start, seq_stop, complexity.
"""
function efetch(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    body = HTTP.escapeuri(params)
    return request("POST", string(baseURL, "efetch.fcgi"), body=body, retry_non_idempotent=true)
end

"""
    elink(ctx=Dict(); params...)

Retrieve UIDs linked to an input set of UIDs.

Parameters: db, dbfrom, cmd, id, query_key, WebEnv, linkname, term, holding,
datetype, reldate, mindate, maxdate.
"""
function elink(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    body = HTTP.escapeuri(params)
    return request("POST", string(baseURL, "elink.fcgi"), body=body, retry_non_idempotent=true)
end

"""
    egquery(ctx=Dict(); params...)

Retrieve the number of available records in all databases by a text query.

Parameters: term.
"""
function egquery(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    return request("GET", string(baseURL, "egquery.fcgi"), query=params)
end

"""
    espell(ctx=Dict(); params...)

Retrieve spelling suggestions.

Parameters: db, term.
"""
function espell(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    return request("GET", string(baseURL, "espell.fcgi"), query=params)
end

"""
    ecitmatch(ctx=Dict(); params...)

Retrieve PubMed IDs that correspond to a set of input citation strings.

Parameters: db, rettype, bdata.
"""
function ecitmatch(ctx::AbstractDict=empty_context(); params...)
    params = process_parameters(params, ctx)
    return request("GET", string(baseURL, "ecitmatch.cgi"), query=params)
end

# create and handle an HTTP request
function request(method::String, URL::String; params...)
    exception = nothing

    # retry request up to four times
    for i in 1:4
        try
            return HTTP.request(method, URL; status_exception=true, params...)
        catch e
            local found_header = false
            exception = e
            # here we find the Retry-After header and sleep for the specified amount of time
            if isa(e, HTTP.StatusError) && e.response.status == 429
                for (header, value) in e.response.headers
                    if (header == "Retry-After")
                        found_header = true
                        sleep(parse(Int, value))
                        break
                    end
                end

                # if the header wasn't found, sleep for 2 seconds
                if !found_header
                    sleep(2)
                end
            else
                # we only handle HTTP 429, so for any other status, throw the error
                rethrow
            end
        end
    end

    # if we get here, we should have run out of retries
    throw(exception)
end

# Create an empty context.
function empty_context()
    return Dict{Symbol,Any}()
end

# Set :WebEnv and :query_key values to the context `ctx` from `res`.
function set_context!(ctx, res)
    if res.status != 200
        return ctx
    end

    # extract WebEnv and query_key from the response
    contenttype = Dict(res.headers)["Content-Type"]
    body = deepcopy(res.body)
    data = String(res.body)

    if startswith(contenttype, "text/xml")
        doc = XMLDict.parse_xml(data)
        ctx[:WebEnv] = doc["WebEnv"]
        ctx[:query_key] = doc["QueryKey"]
    elseif startswith(contenttype, "application/json")
        dict = JSON.parse(data)
        ctx[:WebEnv] = dict["esearchresult"]["webenv"]
        ctx[:query_key] = dict["esearchresult"]["querykey"]
    end
    res.body = body

    return ctx
end

# Process query parameters.
function process_parameters(params, ctx)
    # merge context `ctx` into `params`
    params = merge(ctx, Dict(params))

    # flatten a set of IDs into a comma-separated string
    if haskey(params, :id)
        ids = params[:id]
        if isa(ids, AbstractString)
            ids = [ids]
        end
        params[:id] = join([string(id) for id in ids], ',')
    end

    # normalize the usehistory parameter
    if haskey(params, :usehistory) && isa(params[:usehistory], Bool)
        if params[:usehistory]
            params[:usehistory] = "y"
        else
            delete!(params, :usehistory)
        end
    end

    # stringify all values
    for (key, val) in params
        params[key] = string(val)
    end

    return params
end

end
