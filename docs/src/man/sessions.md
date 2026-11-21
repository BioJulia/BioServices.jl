```@meta
CurrentModule = BioServices.Sessions
```

# Sessions

The service modules perform no I/O. Their functions return requests, as plain data, and sessions run them.

```julia
using BioServices.Sessions, BioServices.EUtils
using Downloads                                  # or HTTP: loading one makes its client available

s = Session(DownloadsClient(), EUtilsAPI())      # or Session(HTTPClient(), EUtilsAPI())
res = run(s, einfo(db = "pubmed"))               # or einfo(db = "pubmed") |> s
res.status, header(res, "Content-Type"), text(res)
```

A session is for one service, and holds everything its requests need:
- the HTTP client, which you always choose: `HTTPClient()` needs HTTP.jl, and `DownloadsClient()` needs Downloads.jl, the standard library's libcurl client;
- the service's configuration, such as its credentials;
- the service's policies: timeouts, retries, redirects, rate limit, and which query parameters to keep out of errors;
- its own rate limiter.

## Combining sessions

Sessions combine as a vector, or a tuple, which runs each request with the session for its service:

```julia
ss = [Session(DownloadsClient(), EUtilsAPI(api_key = ENV["NCBI_API_KEY"])),
      Session(HTTPClient(), UMLSAPI(apikey = ENV["UMLS_APIKEY"])),
      Session(DownloadsClient(), GGGenomeAPI())]
run(ss, esearch(db = "pubmed", term = "obesity"))
run(ss, get_cui(tgt, "C0028754"))
```

The first session for a service wins, so `[override; ss]` overrides a service.
Running a request to a service with no session throws an `ArgumentError`, and so does running it with a single session for another service.
Each session keeps its own limiter, so traffic to one service never delays another.
A service type defined in another package needs nothing more than a session in the vector.

## Tuned policies

Each service has policies chosen from what it is known to do.

| Service | Timeouts (connect, read) | Retries | Redirects | Rate | Keys |
|:--|:--|:--|:--|:--|:--|
| `EBIProteinsAPI` | 10 s, 60 s | 4 tries on 429 and 5xx | same scheme | unlimited | — |
| `UniProtAPI` | 10 s, 60 s | 4 tries on 429 and 5xx | same scheme | unlimited | — |
| `GGGenomeAPI` | 10 s, 60 s | 3 tries on 429, 502, 503, 504 | same scheme | unlimited | — |
| `UMLSAPI` | 10 s, 30 s | 4 tries on 429 and 5xx | same scheme | 20 per second | `apiKey` and `ticket` kept out of errors |
| `EUtilsAPI` | 10 s, 30 s | 4 tries on 429 and 5xx | same scheme | 3 per second, or 10 with a key | `api_key` added to every request and kept out of errors |
| `Generic` | 10 s, 30 s | 3 tries on 429 | any scheme | unlimited | — |

A `Retry-After` header sets the wait before the next try.
GGGenome redirects some https URLs to plain http, and same-scheme redirects refuse that downgrade.

## Configuring sessions

The constructor's keywords override policies, and [`configure`](@ref) returns a new session, leaving the old one as it was:

```julia
s = Session(DownloadsClient(), GGGenomeAPI(); timeouts = Timeouts(10, 300))
s = configure(s; retries = NoRetry())
s = configure(s; client = HTTPClient())            # another client, the same policies
e = configure(e, EUtilsAPI(api_key = ENV["NCBI_API_KEY"]))   # the key is added to requests, and the limit rises to 10 per second
```

With combined sessions, `configure` configures every session for a service and returns the combination:

```julia
ss = configure(ss, GGGenomeAPI; timeouts = Timeouts(10, 300))
ss = configure(ss, EUtilsAPI(api_key = ENV["NCBI_API_KEY"]))
```

Policies you set are kept when you change a service's configuration later.
A session keeps its rate limiter unless its rate limit changes.
Copies of a session share its limiter.
NCBI and NLM count requests per IP address or per key, so put the same session in each place that sends to the service, rather than a new one.

## Requests and workflows

A [`Request`](@ref) is one HTTP request to a service, as plain data.
A [`Workflow`](@ref) runs several requests: it is a function of the sessions that run it, and runs its requests with them.

```julia
w = Workflow() do ss
    ticket = run(ss, get_ticket(tgt))
    JSON.parse(text(run(ss, Request{UMLSAPI}("GET", url; query = ["ticket" => ticket]))))
end
run(s, w)
```

- `map(f, d)` applies `f` to the result of `d`.
- [`configuration`](@ref)`(ss, S)` is the configuration of service `S`, such as its credentials.
- [`unfold`](@ref)`(page, stop)` is a paged sequence, whose result is a lazy iterator.

```julia
pages = run(s, search_umls(tgt, query))           # every page, each with a new ticket
first(run(s, search_pages(tgt, query)))           # only the first page is requested
```

## Endpoint types

Any type can be run once it converts to a request with a `Request(x)` method.
That is how an endpoint type, one per operation of an API, joins in:

```julia
Base.@kwdef struct ProteinsByAccession       # or JSON.@kwarg
    accession::String
    format::Union{Nothing, String} = nothing
end

Sessions.Request(e::ProteinsByAccession) =
    Request{EBIProteinsAPI}("GET", "https://www.ebi.ac.uk/proteins/api/proteins/" * Sessions.escapeuri(e.accession);
                            query = filter(!isnothing ∘ last, ["format" => e.format]))

run(s, ProteinsByAccession(accession = "P08069"))
map(text, Request(ProteinsByAccession(accession = "P08069")))   # a workflow whose result is the body
```

The endpoint holds what the caller asked for, and the session decides how it is sent: retries, rate limit, redirects and keys.
A generated client defines one generic method, `Request(e::Endpoint)`, from each endpoint's method, path, query and body, rather than one method per type.
`unfold` takes endpoints too, so `unfold(n -> Search(query = q, page = n), stop)` is a paged sequence.

## Errors

A response with a status of 400 or more throws a [`StatusError`](@ref), after the service's retries.
A failure to connect or read throws a [`TransportError`](@ref), and a refused redirect a [`RedirectError`](@ref).
Their messages show the URL with redacted parameters as `***`.

## Reference

```@docs
Session
configure
configuration
Base.run(::Session, ::Any)
Request
Response
header
text
url
Workflow
unfold
Timeouts
Retry
Redirects
RateLimit
UniProtAPI
EUtilsAPI
UMLSAPI
StatusError
TransportError
RedirectError
```
