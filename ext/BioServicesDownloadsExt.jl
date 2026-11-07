# Send session requests with Downloads.jl, the standard library's libcurl client:
#
#     using BioServices.Sessions, Downloads
#     s = Session(DownloadsClient())
#
# The session follows redirects itself, so curl is told not to.
module BioServicesDownloadsExt

using BioServices.Sessions: Sessions, DownloadsClient, Timeouts, Request, Response, url
import Downloads
using Downloads.Curl: setopt, CURLOPT_FOLLOWLOCATION

nofollow(easy, info) = setopt(easy, CURLOPT_FOLLOWLOCATION, false)

# One downloader for every client that is given none, so connections stay open between requests.
const SHARED = Ref{Downloads.Downloader}()

function __init__()
    SHARED[] = Downloads.Downloader()
    return SHARED[].easy_hook = nofollow
end

downloader(::DownloadsClient{Nothing}) = SHARED[]
downloader(c::DownloadsClient{Downloads.Downloader}) = (c.downloader.easy_hook = nofollow; c.downloader)

function Sessions.perform(c::DownloadsClient, t::Timeouts, r::Request)
    out = IOBuffer()
    res = Downloads.request(
        url(r);
        method = r.method, headers = r.headers, input = isempty(r.body) ? nothing : IOBuffer(r.body), output = out,
        timeout = t.connect + t.read, throw = false, downloader = downloader(c)
    )
    return outcome(res, out, r)
end

outcome(res::Downloads.Response, out, r) = Response(res.status, res.headers, take!(out), r)
outcome(err::Downloads.RequestError, out, r) = err

end # module BioServicesDownloadsExt
