# Send session requests with HTTP.jl:
#
#     using BioServices.Sessions, HTTP
#     s = Session(HTTPClient())
#
# The session follows redirects and retries itself, so HTTP.jl is asked to do neither.
module BioServicesHTTPExt

using BioServices.Sessions: Sessions, HTTPClient, Timeouts, Request, Response, url
import HTTP

function Sessions.perform(::HTTPClient, t::Timeouts, r::Request)
    res = HTTP.request(
        r.method, url(r), r.headers, r.body;
        connect_timeout = t.connect, read_idle_timeout = t.read,
        redirect = false, retry = false, status_exception = false, cookies = false
    )
    return Response(res.status, map(h -> String(first(h)) => String(last(h)), collect(res.headers)), Vector{UInt8}(res.body), r)
end

end # module BioServicesHTTPExt
