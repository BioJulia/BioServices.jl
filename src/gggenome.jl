# GGGenome
# ======
#
# APIs for GGGenome.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
GGGenome module.

The `GGGenome` module provides a programming interface to GGGenome, 
an ultrafast DNA sequence search service, hosted by DBCLS.
Two functions are exported from this module:
1. `gggenome`: DNA sequence search
2. `gggenome_dblist`: List of available databases
See "GGGenome Help" (https://gggenome.dbcls.jp/en/help.html) for more details.
"""
module GGGenome

export
    gggsearch,
    gggdbs


import HTTP

const baseURL = "https://gggenome.dbcls.jp/"
const dblistURL = "https://raw.githubusercontent.com/meso-cacase/GGGenome/master/DBlist.pm"


# APIs of GGGenome
# -------------------

"""
    gggsearch(query::AbstractString; 
              db="hg19", k=0, strand=nothing, 
              format="html", timeout=5, 
              output=nothing, show_url=false)

Retrieve results of gggenome search of a query sequence.

# Arguments
## Required 
- `query::String`: Nucleotide sequence, case insensitive.

## Optional
- `db::String`: Target database name. hg19 if not specified. Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list
- `k::Integer`: Maximum number of mismatches/gaps. 0 if not specified.
- `strand::String`: '+' ('plus') or '-' ('minus') to search specified strand only.
- `format::String`: [html|txt|csv|bed|gff|json]. html if not specified.
- `timeout::Real`: Maximum time allowed for a query.
- `output::String`: If "toString", a `String` object is returned. If
  "extractTopHit", a `String` object containing only top hit is returned
  (Currently, only works with format="txt"). Otherwise, a
  `HTTP.Messages.Response` object is returned.
- `show_url::Bool`: If true, print URL of REST API.
"""
function gggsearch(query::AbstractString; 
                    db::AbstractString="hg19", k::Integer=0, strand=nothing, format::AbstractString="html", 
                    timeout::Real=5, output=nothing, show_url::Bool=false)
    # Check parameters
    if !checkQuery(query)
        throw(ArgumentError("`query` must be consisted of [A|C|G|T|U|N|R|Y|K|M|S|W|B|D|H|V]"))
    end
    if format ∉ ("html", "txt", "csv", "bed", "gff", "json")
        throw(ArgumentError("`format` must be [html|txt|csv|bed|gff|json]"))
    end
    if strand != nothing && strand ∉ ("+", "-")
        throw(ArgumentError("`output` must be \"+\" or \"-\""))
    end
    if output != nothing && output ∉ ("toString", "extractTopHit")
        throw(ArgumentError("`output` must be \"toString\" or \"extractTopHit\""))
    end

    # Generate URL
    url = baseURL
    url *= db * "/"
    url *= string(k) * "/"
    if strand isa AbstractString
        url *= strand * "/"
    end
    url *= query
    url *= "." * format

    # Show URL
    if show_url
        println(url)
    end

    # Request
    res = HTTP.request("GET", url, timeout=timeout)

    # Output
    if output isa AbstractString
        if output == "toString"
            return gggenomeToString(res)
        elseif output == "extractTopHit" && format == "txt"
            return extractTopHit(gggenomeToString(res))
        else
            # unreachable
            @assert false
        end
    else
        return res
    end
end

function checkQuery(query::AbstractString)
    return all(c -> c ∈ "NRYKMSWBDHVACGTU", query)
end

function gggenomeToString(res::HTTP.Messages.Response)
    return String(res.body)
end

function extractTopHit(res_str::String)
    topResult = "No hit"
    header = ""
    for ln in split(chomp(res_str), "\n")
        if startswith(ln, '#')
            header *= String(ln) * "\n"
        else
            topResult = header * String(ln)
            break
        end
    end
    return topResult
end

"""
    gggdbs()

Retrieve full list of available databases.
Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list.
"""
function gggdbs()
    res = HTTP.request("GET", dblistURL)
    arr = split(String(res.body), "\n")
    index_l = 0
    index_r = 0
    for i in 1:length(arr)
        if startswith("<<'--EOS--' ;", arr[i])
            index_l = i + 1
        elseif startswith("--EOS--", arr[i])
            index_r = i - 1
            break
        end
    end
    return arr[index_l:index_r]
end

end
