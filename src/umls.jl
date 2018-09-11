# UMLS
# ====
#
# Julia utilities to interact with the Unified Medical Language System (UMLS) REST API
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
    BioServices.UMLS

Julia interface to [Unified Medical Language REST API](https://github.com/HHS/uts-rest-api)

The UMLS provides basic functionality to authenticate and query the UMLS API.
The following functions are exported from this module:
1. `get_tgt`: Get Ticket-Granting Ticket
2. `search_umls`: Search the UMLS
3. `best_match_cui`: Get the best matching CUI for a term
4. `get_cui`: Get Concept ID
5. `get_semantic_types`: Get UMLS semantic type

See "UMLS REST API Home Page"
(https://documentation.uts.nlm.nih.gov/rest/home.html) for more details.
"""
module UMLS

export get_tgt,
       search_umls,
       best_match_cui,
       get_cui,
       get_semantic_types

using Gumbo
import HTTP
import JSON
using Dates

#------------- Endpoints -----------------------
const uri = "https://utslogin.nlm.nih.gov"
const service = "http://umlsks.nlm.nih.gov"
const rest_uri = "https://uts-ws.nlm.nih.gov"
#----------------------------------------------

#-------------- Common Utils--------------------
struct BadResponseException <: Exception
    code::Int64
end

function Base.showerror(io::IO, e::BadResponseException)
    print(io, "BadResponseException with code: ",STATUS_CODES[e.code])
end

#-------------- Authentication -------------------
"""
    time_to_last_save(file)

Get how many hours since last save
"""
function time_to_last_save(file)
    #unix time is GMT
    time_diff = Dates.value(now() - Dates.unix2datetime(mtime(file)))/ (1000 * 60 * 60)
    return time_diff
end

"""
    tgt_exists(; tgt_file = "UTS_TGT.txt", hours = 1)

Check if there is a TGT in disk and if it has not expired
"""
function tgt_exists(; tgt_file = "UTS_TGT.txt", hours = 1)
    if isfile(tgt_file)
        #check time
        time_elapsed = time_to_last_save(tgt_file)
        # Expiration time should be 8 hours - but I tend to expirience bad TGT after few hours
        if time_elapsed > hours
            @info "UTS TGT Expired"
            rm(tgt_file)
            return false
        else
            return true
        end
    end
    return false
end


"""
    get_tgt(; force_new::Bool = false, kwargs...)

Retrieve a ticket granting ticket (TGT) using

1. UTS username and password OR
2. apikey

A tgt is valid for 8 hours. Therefore, look for UTS_TGT.txt in the local
directory to see if it has been recently stored. One can force getting a
new ticket by passing keyword argument `force_new=true`

####Examples

```julia
tgt = get_tgt(username = "myuser", password = "mypass")
```

```julia
tgt = get_tgt(apikey = "mykey")
```
"""
function get_tgt(; force_new::Bool = false, kwargs...)
    params = Dict(kwargs)
    body = HTTP.escapeuri(params)
    auth_endpoint = "/cas/v1/tickets/"

    if !haskey(params, :apikey)
        if !haskey(params, :username) && !haskey(params, :password)
            error("UMLSRestAPI: Connection requieres passing keword arguments: apikey or username and password")
        end
    else
        auth_endpoint = "/cas/v1/api-key"
    end

    # Check if there is a valid ticket on disk
    tgt_file = "UTS_TGT.txt"
    if tgt_exists(tgt_file=tgt_file) && !force_new
        @info "UTS: Reading TGT from file"
        return readline(tgt_file)
    end

    @info "UTS: Requesting new TGT"
    headers = Dict("Content-type"=> "application/x-www-form-urlencoded",
    "Accept"=> "text/plain", "User-Agent"=>"julia" )
    r = HTTP.request("POST", uri*auth_endpoint, body=body, headers=headers)
    ascii_r = String(r.body)

    doc = parsehtml(ascii_r)
    #for now - harcoded
    #TO DO:: parse and check
    ticket = ""
    try
        ticket = getattr(doc.root.children[2].children[2], "action")
    catch
        error("Could not get TGT: Unexpected structure of UTS response")
    end

    open(tgt_file, "w") do f
        write(f, ticket)
    end

    return ticket
end

"""
    get_ticket(tgt)

Retrieve a single-use Service Ticket using TGT
"""
function get_ticket(tgt)
    params = Dict("service"=> service)
    body = HTTP.escapeuri(params)

    headers = Dict("Content-type"=> "application/x-www-form-urlencoded",
    "Accept"=> "text/plain", "User-Agent"=>"JuliaBioServices" )
    r = HTTP.Response(503)
    try
        r = HTTP.request("POST", tgt; body=body, headers=headers, retry_non_idempotent=true)
    catch
        isdefined(r, :code) ? error("UMLS GET error: ", r.code) : error("UMLS COULD NOT GET")
    end
    return String(r.body)
end

#------------------Search ---------------------
"""
    search_umls(tgt, query)

Search UMLS Rest API. For more info see
[UMLS_API](https://documentation.uts.nlm.nih.gov/rest/search/)


####Arguments

- `tgt`: Ticket Granting Ticket
- `query`: UMLS query containing the search term
- `version:` Optional - defaults to current

####Output

- `result_pages`: Array, where each entry is a dictionary containing a page of
results. e.g
```julia
Dict{AbstractString,Any} with 3 entries:
"pageSize"   => 25
"pageNumber" => 1
"result"     => Dict{AbstractString,Any}("classType"=>"searchResults","result…
```

####Examples

```julia
credentials = Credentials(user, psswd)
tgt = get_tgt(credentials)
term = "obesity"
query = Dict("string"=>term, "searchType"=>"exact" )
all_results= search_umls(tgt, query)
```
"""
function search_umls(tgt, query; version::String="current", timeout=1)
    page = 0
    content_endpoint = "/rest/search/current"

    #each page of results is appended to the output list
    #where each entry is a dictionary containing that pages's results
    # e.g
    # Dict{AbstractString,Any} with 3 entries:
    #   "pageSize"   => 25
    #   "pageNumber" => 1
    #   "result"     => Dict{AbstractString,Any}("classType"=>"searchResults","result…
    result_pages = Array{Any,1}()

    while true

        #get a new ticket per page if necessary
        ticket = ""
        ticket = get_ticket(tgt)

        page +=1
        #append ticket to query
        query["ticket"]= ticket
        query["pageNumber"]= string(page)

        r = HTTP.request("GET", rest_uri*content_endpoint, query=query, timeout=timeout)

        if r.status != 200
            error("Bad HTTP status $(r.status)")
        end

        json_response = JSON.parse(String(r.body))
        # println("No Results ", length(json_response["result"]["results"]))
        if json_response["result"]["results"][1]["ui"]=="NONE"
            break
        end
        push!(result_pages,json_response)
    end

    return result_pages
end

"""
    best_match_cui(result_pages)

Retrieve the best match from array of all result pages

####Example

```julia
cui = best_match_cui(all_results)
```
"""
function best_match_cui(result_pages)
    return result_pages[1]["result"]["results"][1]["ui"]
end

#------------------Content--------------------------------
"""
    get_cui(tgt,cui)

Retrieve information (name, semantic types, number of atoms, etc) for a known CUI
from latest UMLS version or a specific release.

Returns UTS json response

See: https://documentation.uts.nlm.nih.gov/rest/concept

####Example

```julia
tgt = get_tgt(apikey = "mykey")
cui = "C0028754"
concept = get_cui(tgt, cui)
```
"""
function get_cui(tgt,cui; version="current")
    content_endpoint = "/rest/content/$(version)/CUI/"*cui
    #get a new ticket
    ticket = ""
    try
        ticket = get_ticket(tgt)
    catch err
        rethrow(err)
    end

    r = HTTP.Response(503)
    try
        r = HTTP.request("GET", rest_uri*content_endpoint,query=Dict("ticket"=> ticket))
    catch
        isdefined(r, :code) ? error("UMLS GET error: ", r.code) : error("UMLS COULD NOT GET")
    end

    return JSON.parse(String(r.body))
end


"""
    get_semantic_types(c::Credentials, cui)

Return an array of the semantic types associated with a cui

####Example

```julia
tgt = get_tgt(apikey = "mykey")
cui = "C0028754"
sm = get_semantic_types(tgt, cui)
```
"""
function get_semantic_types(tgt, cui; version="current")
    json_response = get_cui(tgt,cui; version=version)
    st = json_response["result"]["semanticTypes"]
    return [String(concept["name"]) for concept in st]
end

end
