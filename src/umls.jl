# UMLS
# ====
#
# Julia utilities to interact with the Unified Medical Language System (UMLS) REST API
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioServices.jl/blob/master/LICENSE.md

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

See "UMLS REST API Home Page" (https://documentation.uts.nlm.nih.gov/rest/home.html) for more details.

Each function returns a request, or a workflow of requests, which a session runs:

    using BioServices.Sessions, BioServices.UMLS, Downloads
    s = Session(DownloadsClient(), UMLSAPI(apikey = ENV["UMLS_APIKEY"]))
    tgt = run(s, get_tgt())
    run(s, get_semantic_types(tgt, "C0028754"))
"""
module UMLS

export get_tgt,
    search_umls,
    search_pages,
    best_match_cui,
    get_cui,
    get_semantic_types

using Gumbo
import JSON
using Dates
using ..Sessions: Request, Workflow, UMLSAPI, configuration, escapeuri, form, text, unfold

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
    return print(io, "BadResponseException with code: ", e.code)
end

const FORM = ["Content-type" => "application/x-www-form-urlencoded", "Accept" => "text/plain", "User-Agent" => "JuliaBioServices"]

#-------------- Authentication -------------------
"""
    time_to_last_save(file)

Get how many hours since last save
"""
function time_to_last_save(file)
    #unix time is GMT
    time_diff = Dates.value(now() - Dates.unix2datetime(mtime(file))) / (1000 * 60 * 60)
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
    get_tgt(; force_new::Bool = false, tgt_file = "UTS_TGT.txt", kwargs...)

Describe the retrieval of a ticket granting ticket (TGT) using

1. UTS username and password OR
2. apikey OR
3. with neither, the apikey of the session's `UMLSAPI`.

A tgt is valid for 8 hours.
Therefore, when the workflow runs, it looks for `tgt_file` in the local directory to see if it has been recently stored.
One can force getting a new ticket by passing keyword argument `force_new=true`.

####Examples

```julia
tgt = run(s, get_tgt(username = "myuser", password = "mypass"))
```

```julia
tgt = run(s, get_tgt(apikey = "mykey"))
```
"""
function get_tgt(; force_new::Bool = false, tgt_file = "UTS_TGT.txt", kwargs...)
    given = Dict{Symbol, Any}(kwargs)
    isempty(given) || endpoint(given)  # check the credentials now, before anything runs
    return Workflow() do ss
        !force_new && tgt_exists(tgt_file = tgt_file) && return cached_tgt(tgt_file)
        run(ss, request_tgt(isempty(given) ? session_credentials(configuration(ss, UMLSAPI)) : given, tgt_file))
    end
end

session_credentials(s::UMLSAPI) = s.apikey === nothing ?
    error("UMLSRestAPI: Connection requieres passing keword arguments: apikey or username and password, or a session configured with UMLSAPI(apikey = ...)") :
    Dict{Symbol, Any}(:apikey => s.apikey)

endpoint(c) = haskey(c, :apikey) ? "/cas/v1/api-key" :
    haskey(c, :username) || haskey(c, :password) ? "/cas/v1/tickets/" :
    error("UMLSRestAPI: Connection requieres passing keword arguments: apikey or username and password")

function cached_tgt(tgt_file)
    @info "UTS: Reading TGT from file"
    return readline(tgt_file)
end

function request_tgt(c, tgt_file)
    @info "UTS: Requesting new TGT"
    return map(res -> save_tgt(tgt_file, parse_tgt(text(res))), Request{UMLSAPI}("POST", uri * endpoint(c); headers = FORM, body = form(c)))
end

#for now - harcoded
#TO DO:: parse and check
function parse_tgt(html)
    try
        return getattr(parsehtml(html).root.children[2].children[2], "action")
    catch
        error("Could not get TGT: Unexpected structure of UTS response")
    end
end

save_tgt(tgt_file, ticket) = (write(tgt_file, ticket); ticket)

"""
    get_ticket(tgt)

Describe the retrieval of a single-use Service Ticket using TGT.
"""
get_ticket(tgt) = map(text, Request{UMLSAPI}("POST", tgt; headers = FORM, body = form(["service" => service])))

#------------------Search ---------------------
"""
    search_umls(tgt, query; version = "current")

Describe a search of the UMLS Rest API.
For more info see [UMLS_API](https://documentation.uts.nlm.nih.gov/rest/search/)


####Arguments

- `tgt`: Ticket Granting Ticket
- `query`: UMLS query containing the search term
- `version:` Optional - defaults to current

The timeout of each page is a policy of the session's `UMLSAPI`.

####Output

- `result_pages`: Array, where each entry is a dictionary containing a page of
results. e.g
```julia
Dict{AbstractString,Any} with 3 entries:
"pageSize"   => 25
"pageNumber" => 1
"result"     => Dict{AbstractString,Any}("classType"=>"searchResults","result…
```

[`search_pages`](@ref) describes the same pages as a lazy iterator.

####Examples

```julia
tgt = run(s, get_tgt(apikey = "mykey"))
term = "obesity"
query = Dict("string"=>term, "searchType"=>"exact" )
all_results = run(s, search_umls(tgt, query))
```
"""
search_umls(tgt, query; version::String = "current") = map(collect, search_pages(tgt, query; version = version))

"""
    search_pages(tgt, query; version = "current")

Describe the pages of a search of the UMLS Rest API, as [`search_umls`](@ref) does, but with a lazy iterator as the result: each page is requested as it is reached.

####Example

```julia
first_page = first(run(s, search_pages(tgt, query)))   # only the first page is requested
```
"""
search_pages(tgt, query; version::String = "current") = unfold(n -> search_page(tgt, query, version, n), isnone)

# Each page needs a new ticket.
search_page(tgt, query, version, n) = Workflow() do ss
    ticket = run(ss, get_ticket(tgt))
    params = merge(Dict{String, Any}(query), Dict("ticket" => ticket, "pageNumber" => string(n)))
    JSON.parse(text(run(ss, Request{UMLSAPI}("GET", rest_uri * "/rest/search/" * escapeuri(version); query = params))))
end

# The search ends at a page whose only result is "NONE".
isnone(json) = json["result"]["results"][1]["ui"] == "NONE"

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

Describe the retrieval of information (name, semantic types, number of atoms, etc) for a known CUI from latest UMLS version or a specific release.

Its result is the UTS json response

See: https://documentation.uts.nlm.nih.gov/rest/concept

####Example

```julia
tgt = run(s, get_tgt(apikey = "mykey"))
cui = "C0028754"
concept = run(s, get_cui(tgt, cui))
```
"""
get_cui(tgt, cui; version = "current") = Workflow() do ss
    ticket = run(ss, get_ticket(tgt))
    JSON.parse(text(run(ss, Request{UMLSAPI}("GET", rest_uri * "/rest/content/" * escapeuri(version) * "/CUI/" * escapeuri(cui); query = ["ticket" => ticket]))))
end


"""
    get_semantic_types(tgt, cui)

Describe the retrieval of an array of the semantic types associated with a cui

####Example

```julia
tgt = run(s, get_tgt(apikey = "mykey"))
cui = "C0028754"
sm = run(s, get_semantic_types(tgt, cui))
```
"""
get_semantic_types(tgt, cui; version = "current") =
    map(json -> map(concept -> String(concept["name"]), json["result"]["semanticTypes"]), get_cui(tgt, cui; version = version))

end
