import HTTP
using URIs: escapeuri

"""
    escape(x)

Percent-encode the string of `x` for a URL path segment or query value.
"""
escape(x) = escapeuri(string(x))

"""
    form(params)

Encode `params`, any collection of pairs, as `application/x-www-form-urlencoded`.
Pairs whose value is `nothing` are left out.
"""
form(params) = escapeuri(stringpairs(params))

"""
    url(base, segments...; query = ())

The URL of `base` followed by the path `segments`, each percent-encoded and separated by `/`, and the query string of `query`.
`query` takes any collection of pairs, and is appended with `&` when the URL already has a query string.
"""
function url(base::AbstractString, segments...; query = ())
    path = isempty(segments) ? String(base) : string(base, join(map(escape, segments), '/'))
    q = form(query)
    return isempty(q) ? path : string(path, occursin('?', path) ? '&' : '?', q)
end

# The pairs of `params` as strings, without those whose value is `nothing`.
stringpairs(params) = [string(first(p)) => string(last(p)) for p in pairsof(params) if last(p) !== nothing]

pairsof(params::Union{AbstractDict, AbstractVector{<:Pair}, Tuple{Vararg{Pair}}}) = params
pairsof(params) = pairs(params)

# Create an HTTP request.
# HTTP.jl retries 408, 429, 500, 502, 503, and 504 responses, honoring `Retry-After`, and throws an `HTTP.StatusError` for any other status of 300 or more (except redirects).
# Every module sends its requests through here, with the URL built by `url` and form bodies encoded by `form`.
function request(method::AbstractString, URL::AbstractString, headers = Pair{String, String}[]; params...)
    return HTTP.request(method, URL, headers; params...)
end
