# GGGenome
# ======
#
# APIs for GGGenome.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioServices.jl/blob/master/LICENSE.md

"""
GGGenome module.

The `GGGenome` module provides a programming interface to GGGenome, an ultrafast DNA sequence search service, hosted by DBCLS.
Two functions are exported from this module:
1. `gggsearch`: DNA sequence search
2. `gggdbs`: List of available databases
See "GGGenome Help" (https://gggenome.dbcls.jp/en/help.html) for more details.

Both functions return requests, which a session runs:

    using BioServices.Sessions, BioServices.GGGenome, Downloads
    s = Session(DownloadsClient(), GGGenomeAPI())
    res = run(s, gggsearch("TTCATTGACAACATT", db = "felCat5", format = "txt"))
"""
module GGGenome

export
    gggsearch,
    gggdbs

using ..Sessions: Request, Response, GGGenomeAPI, escapeuri, text

const baseURL = "https://gggenome.dbcls.jp/"
const dblistURL = "https://raw.githubusercontent.com/meso-cacase/GGGenome/master/DBlist.pm"


# APIs of GGGenome
# -------------------

"""
    gggsearch(query::AbstractString;
              db="hg19", k=0, strand=nothing,
              format="html", output=nothing)

Describe a gggenome search of a query sequence.

# Arguments
## Required
- `query::String`: Nucleotide sequence, case insensitive.

## Optional
- `db::String`: Target database name. hg19 if not specified.
  Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list
- `k::Integer`: Maximum number of mismatches/gaps.
  0 if not specified.
- `strand::String`: '+' ('plus') or '-' ('minus') to search specified strand only.
- `format::String`: [html|txt|csv|bed|gff|json]. html if not specified.
- `output::String`: If "toString", the result is a `String`.
  If "extractTopHit", the result is a `String` containing only the top hit, and `format` must be "txt".
  Otherwise, the result is the `Response`.

The URL of a search is `Sessions.url(gggsearch(...))`.
The timeout is a policy of the session: `configure(s; timeouts = Timeouts(10, 120))`.
GGGenome redirects some URLs with default segments to plain http, which the session refuses, so `k = 0` is left out of the URL.
"""
function gggsearch(
        query::AbstractString;
        db::AbstractString = "hg19", k::Integer = 0, strand = nothing, format::AbstractString = "html", output = nothing
    )
    checkQuery(query) || throw(ArgumentError("`query` must be consisted of [A|C|G|T|U|N|R|Y|K|M|S|W|B|D|H|V]"))
    format in ("html", "txt", "csv", "bed", "gff", "json") || throw(ArgumentError("`format` must be [html|txt|csv|bed|gff|json]"))
    strand in (nothing, "+", "-") || throw(ArgumentError("`strand` must be \"+\" or \"-\""))
    output in (nothing, "toString", "extractTopHit") || throw(ArgumentError("`output` must be \"toString\" or \"extractTopHit\""))
    output == "extractTopHit" && format != "txt" && throw(ArgumentError("`output = \"extractTopHit\"` needs `format = \"txt\"`"))
    segments = filter(!isnothing, [db, mismatches(k), strand, query * "." * format])
    return result(Val(Symbol(something(output, :response))), Request{GGGenomeAPI}("GET", baseURL * join(map(escapeuri, segments), '/')))
end

mismatches(k) = k == 0 ? nothing : string(k)

result(::Val{:response}, req) = req
result(::Val{:toString}, req) = map(gggenomeToString, req)
result(::Val{:extractTopHit}, req) = map(extractTopHit ∘ gggenomeToString, req)

checkQuery(query::AbstractString) = all(c -> c ∈ "NRYKMSWBDHVACGTU", query)

gggenomeToString(res::Response) = text(res)

function extractTopHit(res_str::AbstractString)
    lines = split(chomp(res_str), "\n")
    header = join(map(ln -> ln * "\n", Iterators.takewhile(ln -> startswith(ln, '#'), lines)))
    hits = Iterators.dropwhile(ln -> startswith(ln, '#'), lines)
    return isempty(hits) ? "No hit" : header * first(hits)
end

"""
    gggdbs()

Describe the retrieval of the full list of available databases; its result is a vector of lines.
Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list.
"""
gggdbs() = map(dblist ∘ text, Request{GGGenomeAPI}("GET", dblistURL))

# The lines of DBlist.pm between its here-document markers.
function dblist(source)
    lines = split(source, "\n")
    after = Iterators.drop(Iterators.dropwhile(ln -> !startswith(ln, "<<'--EOS--'"), lines), 1)
    return collect(Iterators.takewhile(ln -> !startswith(ln, "--EOS--"), after))
end

end
