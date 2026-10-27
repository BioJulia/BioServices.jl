import HTTP

# Create an HTTP request. HTTP.jl retries 408, 429, 500, 502, 503, and 504 responses, honoring
# `Retry-After`, and throws an `HTTP.StatusError` for any other status of 300 or more
# (except redirects).
function request(method::String, URL::String, headers::Vector{Pair{String, String}} = Pair{String, String}[]; params...)
    return HTTP.request(method, URL, headers; status_exception=true, params...)
end
