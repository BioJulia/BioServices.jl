# Sessions
# ========
#
# Sessions that run requests to services, under each service's policies.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioServices.jl/blob/master/LICENSE.md

"""
    Sessions

Sessions run the requests that the service modules describe.

The service modules perform no I/O. Their functions return a [`Request`](@ref), or a [`Workflow`](@ref) that runs several requests.
A [`Session`](@ref) is for one service: it holds the HTTP client, the service's credentials and tuned policies, and its rate limiter.
Sessions combine as a vector, which runs each request with the session for its service.
`run` is the only place where requests are sent.

    using BioServices, Downloads    # loading Downloads (or HTTP) loads its client
    using BioServices.Sessions, BioServices.EUtils

    s = Session(DownloadsClient(), EUtilsAPI())
    res = run(s, einfo(db = "pubmed"))    # or einfo(db = "pubmed") |> s
    ss = [s, Session(DownloadsClient(), GGGenomeAPI())]
    run(ss, gggsearch("hg38", "TTCATTGACAACATTGCGT"))

Each service's policies are chosen from what it is known to do:
- [`EBIProteinsAPI`](@ref) and [`UniProtAPI`](@ref): retry 429 and 5xx responses, honouring `Retry-After`.
- [`GGGenomeAPI`](@ref): a long read timeout, and no redirects from https to http.
- [`UMLSAPI`](@ref): 20 requests per second, and API keys and tickets kept out of errors.
- [`EUtilsAPI`](@ref): 3 requests per second, or 10 with an API key, which is added to every request and kept out of errors.

[`configure`](@ref) returns a new session, or a new vector of sessions, with credentials, policies or the client changed.
"""
module Sessions

export
    # Sessions.
    Session, configure, configuration,
    # Requests and workflows.
    Request, Workflow, unfold,
    # Responses and errors.
    Response, StatusError, TransportError, RedirectError, header, text, url,
    # Clients.
    Client, HTTPClient, DownloadsClient,
    # Services.
    Service, EBIProteinsAPI, UniProtAPI, GGGenomeAPI, UMLSAPI, EUtilsAPI, Generic,
    # Policies.
    Timeouts, Retry, NoRetry, Exponential, Fixed, Redirects, NoRedirects, SameScheme, AnyScheme,
    RateLimit, Unlimited, Redact, NoAuth, QueryKey

using URIs: URI, escapeuri, resolvereference


# Services
# --------

"""
    Service

Supertype of the services a session can talk to.
A service value is that service's configuration, credentials included.
"""
abstract type Service end

"The EBI Proteins API, https://www.ebi.ac.uk/proteins/api/."
struct EBIProteinsAPI <: Service end

"The UniProt REST API, https://rest.uniprot.org/."
struct UniProtAPI <: Service end

"GGGenome, https://gggenome.dbcls.jp/."
struct GGGenomeAPI <: Service end

"""
    UMLSAPI(; apikey = nothing)

The UMLS Terminology Services, https://uts-ws.nlm.nih.gov/. `apikey` is the UTS API key that `UMLS.get_tgt` uses when it is given no credentials.
"""
struct UMLSAPI <: Service
    apikey::Union{Nothing, String}
end
UMLSAPI(; apikey = nothing) = UMLSAPI(apikey)
Base.show(io::IO, s::UMLSAPI) = print(io, "UMLSAPI(apikey = ", secret(s.apikey), ")")

"""
    EUtilsAPI(; api_key = nothing)

NCBI's Entrez Programming Utilities, https://eutils.ncbi.nlm.nih.gov/. With an `api_key`, it is added to every request and the rate limit rises from 3 to 10 requests per second.
"""
struct EUtilsAPI <: Service
    api_key::Union{Nothing, String}
end
EUtilsAPI(; api_key = nothing) = EUtilsAPI(api_key)
Base.show(io::IO, s::EUtilsAPI) = print(io, "EUtilsAPI(api_key = ", secret(s.api_key), ")")

# Credentials are shown masked, so printing a session in the REPL or a log doesn't reveal them.
secret(::Nothing) = "nothing"
secret(::AbstractString) = "\"***\""

"Any other host; it has the most permissive policies."
struct Generic <: Service end


# Policies
# --------

"""
    Timeouts(connect, read)

Seconds to wait for a connection, and for data once connected.
Downloads.jl has only a timeout for the whole transfer, so with `DownloadsClient` it is `connect + read`.
"""
struct Timeouts
    connect::Float64
    read::Float64
end

"How long to wait before retry `n`, counted from 1."
abstract type Backoff end

"Wait `base * 2^(n - 1)` seconds before retry `n`, and never more than `cap`."
struct Exponential <: Backoff
    base::Float64
    cap::Float64
end

"Wait `seconds` before every retry."
struct Fixed <: Backoff
    seconds::Float64
end

backoff(b::Exponential, n) = min(b.cap, b.base * 2.0^(n - 1))
backoff(b::Fixed, n) = b.seconds

"""
    Retry(tries, statuses, backoff)

Make up to `tries` attempts.
A response whose status is in `statuses` is retried, and so is a failure to connect or read.
A `Retry-After` header replaces the wait that `backoff` gives.
"""
struct Retry{B <: Backoff}
    tries::Int
    statuses::Tuple{Vararg{Int}}
    backoff::B
end

"Make one attempt."
struct NoRetry end

"Follow redirects only to the same scheme, or from http to https."
struct SameScheme end
"Follow redirects to any scheme."
struct AnyScheme end

"""
    Redirects(limit, scheme)

Follow up to `limit` redirects, to the schemes that `scheme` allows: `SameScheme()` or `AnyScheme()`.
"""
struct Redirects{S}
    limit::Int
    scheme::S
end

"Return redirect responses as they are."
struct NoRedirects end

"""
    RateLimit(per_second)

Send at most `per_second` requests per second to a service.
"""
struct RateLimit
    per_second::Float64
end

"Send requests as fast as they come."
struct Unlimited end

"""
    Redact(names)

Query parameters whose values are kept out of errors, such as API keys.
"""
struct Redact
    names::Tuple{Vararg{String}}
end

"Send no credentials."
struct NoAuth end

"Add the query parameter `name = key` to every request."
struct QueryKey
    name::String
    key::String
end

"Seconds to wait for a connection to service `s`, and for its data."
timeouts(::Service) = Timeouts(10, 30)
timeouts(::Union{EBIProteinsAPI, UniProtAPI, GGGenomeAPI}) = Timeouts(10, 60)

const TRANSIENT = (429, 500, 502, 503, 504)

"How failed requests to service `s` are retried."
retries(::Service) = Retry(3, (429,), Exponential(1, 30))
retries(::Union{EBIProteinsAPI, UniProtAPI, UMLSAPI, EUtilsAPI}) = Retry(4, TRANSIENT, Exponential(1, 30))
retries(::GGGenomeAPI) = Retry(3, (429, 502, 503, 504), Exponential(1, 30))

"""
How redirects from service `s` are followed.
GGGenome redirects some https URLs to http, so only same-scheme redirects are followed by default.
"""
redirects(::Service) = Redirects(5, SameScheme())
redirects(::Generic) = Redirects(5, AnyScheme())

"How fast requests may be sent to service `s`."
ratelimit(::Service) = Unlimited()
ratelimit(::UMLSAPI) = RateLimit(20)
ratelimit(s::EUtilsAPI) = ratelimit(s, s.api_key)
ratelimit(::EUtilsAPI, ::Nothing) = RateLimit(3)
ratelimit(::EUtilsAPI, ::AbstractString) = RateLimit(10)

"The query parameters of requests to service `s` that are kept out of errors."
redact(::Service) = Redact(())
redact(::UMLSAPI) = Redact(("apiKey", "ticket"))
redact(::EUtilsAPI) = Redact(("api_key",))

"How requests to service `s` are authorised."
auth(::Service) = NoAuth()
auth(s::EUtilsAPI) = auth(s, s.api_key)
auth(::EUtilsAPI, ::Nothing) = NoAuth()
auth(::EUtilsAPI, key::AbstractString) = QueryKey("api_key", key)

"The policies of service `s` when none are overridden."
defaults(s::Service) = (
    timeouts = timeouts(s),
    retries = retries(s),
    redirects = redirects(s),
    ratelimit = ratelimit(s),
    redact = redact(s),
    auth = auth(s),
)

# The policies of service `s` with `overrides` set; the names must be known policies.
function settings(s::Service, overrides::NamedTuple)
    unknown = setdiff(keys(overrides), keys(defaults(s)))
    isempty(unknown) || throw(ArgumentError("unknown policies $(Tuple(unknown)); the policies are $(keys(defaults(s)))"))
    return merge(defaults(s), overrides)
end


# Rate limiters
# -------------

"""
    Limiter(rate::RateLimit)

The next free slot for requests to one service.
Each session has its own, shared by every `run` on the session and by its copies.
"""
struct Limiter
    rate::RateLimit
    next::Threads.Atomic{Float64}
end
Limiter(r::RateLimit) = Limiter(r, Threads.Atomic{Float64}(0.0))

"The limiter of a service without a rate limit."
struct NoLimiter end

limiter(r::RateLimit) = Limiter(r)
limiter(::Unlimited) = NoLimiter()

rate(l::Limiter) = l.rate
rate(::NoLimiter) = Unlimited()

# A limiter is kept while its rate is unchanged, so reconfiguring a session does not reset its budget.
renew(l, r) = rate(l) == r ? l : limiter(r)
renew(::Nothing, r) = limiter(r)

throttle(::NoLimiter) = nothing
function throttle(l::Limiter)
    now = time()
    slot = reserve(l.next, now, 1 / l.rate.per_second)
    slot > now && sleep(slot - now)
    return
end

# Take the next free slot, at `now` or later, and move it on by `gap`; try again if another task took it first.
function reserve(next, now, gap)
    old = next[]
    slot = max(old, now)
    return Threads.atomic_cas!(next, old, slot + gap) === old ? slot : reserve(next, time(), gap)
end


# Requests and workflows
# ----------------------

const Pairs = Vector{Pair{String, String}}

"""
    Request{S<:Service}(method, url; query = [], headers = [], body = UInt8[])
    Request(x)

One HTTP request to service `S`, as plain data: nothing is sent until a session runs it.
`query` and `headers` take any collection of pairs, such as a `Dict` or keyword arguments, and `body` takes a `String` or bytes.

`Request(x)` converts `x` to a request.
Define a method to make another type runnable, as an endpoint type of a client does:

    Sessions.Request(e::ProteinsByAccession) = Request{EBIProteinsAPI}("GET", base * escapeuri(e.accession))
    run(s, ProteinsByAccession(accession = "P08069"))
"""
struct Request{S <: Service}
    method::String
    url::String
    query::Pairs
    headers::Pairs
    body::Vector{UInt8}
end

function Request{S}(method::AbstractString, url::AbstractString; query = Pairs(), headers = Pairs(), body = UInt8[]) where {S <: Service}
    return Request{S}(String(method), String(url), stringpairs(query), stringpairs(headers), bytes(body))
end

# The pairs of `params` as strings, without those whose value is `nothing`.
stringpairs(params) = Pairs([string(first(p)) => string(last(p)) for p in pairsof(params) if last(p) !== nothing])

pairsof(params::Union{AbstractDict, AbstractVector{<:Pair}, Tuple{Vararg{Pair}}}) = params
pairsof(params::AbstractVector) = collect(Pair, params)
pairsof(params) = pairs(params)

bytes(b::AbstractVector{UInt8}) = Vector{UInt8}(b)
bytes(b::AbstractString) = Vector{UInt8}(codeunits(String(b)))

service(::Request{S}) where {S} = S

# A copy of `r` with some fields replaced.
function with(r::Request{S}; kwargs...) where {S}
    return Request{S}(map(f -> get(kwargs, f, getfield(r, f)), fieldnames(Request))...)
end

"""
    url(r::Request)

The full URL of `r`, with its query string.
"""
url(r::Request) = url(r.url; query = r.query)

"""
    url(base, segments...; query = ())

The URL of `base` followed by the path `segments`, each percent-encoded and separated by `/`, and the query string of `query`.
`query` takes any collection of pairs, and is appended with `&` when the URL already has a query string.
"""
function url(base::AbstractString, segments...; query = ())
    path = isempty(segments) ? String(base) : string(base, join(map(escapeuri, segments), '/'))
    q = form(query)
    return isempty(q) ? path : string(path, occursin('?', path) ? '&' : '?', q)
end

"""
    form(params)

Encode `params`, any collection of pairs, as `application/x-www-form-urlencoded`.
Pairs whose value is `nothing` are left out.
"""
form(params) = escapeuri(stringpairs(params))

"""
    Workflow(f)

Work that is a function of the sessions that run it: `run(ss, Workflow(f))` is `f(ss)`.
Inside `f`, run requests and other workflows with `run(ss, x)`, and read a service's configuration with [`configuration`](@ref):

    get_cui(tgt, cui) = Workflow() do ss
        ticket = run(ss, get_ticket(tgt))
        JSON.parse(text(run(ss, Request{UMLSAPI}("GET", ...; query = ["ticket" => ticket]))))
    end

Nothing runs until the workflow does.
"""
struct Workflow{F}
    f::F
end

"""
    map(f, r::Request)
    map(f, w::Workflow)

A workflow whose result is `f` applied to the result of `r` or `w`.
For another type, map over its request: `map(f, Request(e))`.
"""
Base.map(f, r::Request) = Workflow(ss -> f(run(ss, r)))
Base.map(f, w::Workflow) = Workflow(ss -> f(run(ss, w)))

"""
    unfold(page, stop)

A workflow for a paged sequence, whose result is a lazy iterator: each page is requested as it is reached.
`page(n)` is page `n`, counted from 1, as anything `run` takes: a request, a workflow, or a type with a `Request` method.
The sequence ends before the first result for which `stop` is true.
`map(collect, unfold(page, stop))` requests every page.
"""
unfold(page, stop) = Workflow(ss -> Iterators.takewhile(!stop, Iterators.map(n -> run(ss, page(n)), Iterators.countfrom(1))))


# Responses and errors
# --------------------

"""
    Response

The response to a [`Request`](@ref): `status`, `headers` as a vector of pairs, `body` as bytes, and the `request` that was sent.
"""
struct Response{S <: Service}
    status::Int
    headers::Pairs
    body::Vector{UInt8}
    request::Request{S}
end

"""
    header(r::Response, name, default = "")

The value of the header `name`, ignoring case.
"""
function header(r::Response, name::AbstractString, default = "")
    i = findfirst(p -> lowercase(first(p)) == lowercase(name), r.headers)
    return i === nothing ? default : last(r.headers[i])
end

"The body of `r` as a `String`."
text(r::Response) = String(copy(r.body))

ok(r::Response) = 200 <= r.status < 400
isredirect(r::Response) = r.status in (301, 302, 303, 307, 308)

"""
    StatusError(response, message)

A response with a status of 400 or more.
"""
struct StatusError <: Exception
    response::Response
    message::String
end
Base.showerror(io::IO, e::StatusError) = print(io, "StatusError: ", e.message)

"""
    TransportError(message, cause)

A request that failed before a response arrived: no connection, a timeout, a broken transfer.
"""
struct TransportError <: Exception
    message::String
    cause::Exception
end
Base.showerror(io::IO, e::TransportError) = print(io, "TransportError: ", e.message)

"""
    RedirectError(message)

A redirect that the session's policy refused, or too many redirects.
"""
struct RedirectError <: Exception
    message::String
end
Base.showerror(io::IO, e::RedirectError) = print(io, "RedirectError: ", e.message)

# Replace the values of the redacted query parameters of `r`, as they are and percent-encoded, in `s`.
function mask(x::Redact, r::Request, s::AbstractString)
    secrets = map(last, filter(p -> first(p) in x.names && !isempty(last(p)), r.query))
    return foldl((t, v) -> replace(t, v => "***", escapeuri(v) => "***"), secrets; init = String(s))
end


# Clients
# -------

"""
    Client

Supertype of the HTTP clients a session can send requests with.
Each client's `perform` method is defined by a package extension, so loading the client's package makes it available.
"""
abstract type Client end

"Send requests with HTTP.jl; `using HTTP` loads it."
struct HTTPClient <: Client end

"""
    DownloadsClient(downloader = nothing)

Send requests with Downloads.jl; `using Downloads` loads it.
Without a `Downloads.Downloader`, every `DownloadsClient` shares one, which keeps connections open between requests.
"""
struct DownloadsClient{D} <: Client
    downloader::D
end
DownloadsClient() = DownloadsClient(nothing)

"""
    perform(client, timeouts, request) -> Union{Response, Exception}

Send `request` once, without following redirects, and return the response whatever its status.
A failure to connect or read is returned, not thrown.
"""
function perform end

# A failure to send is a value that the retry policy can inspect; a missing client method is a mistake to report at once.
attempt(c::Client, t::Timeouts, r::Request) =
try
    perform(c, t, r)
catch err
    failure(err)
end
failure(err::MethodError) = throw(err)
failure(err) = err

const PACKAGES = (HTTPClient = "HTTP", DownloadsClient = "Downloads")

function client_hint(io, exc, argtypes, kwargs)
    exc.f === perform && !isempty(argtypes) && argtypes[1] <: Client || return
    name = nameof(argtypes[1])
    pkg = get(PACKAGES, name, nothing)
    pkg === nothing || print(io, "\n$name needs $pkg; load it with `using $pkg`.")
    return
end

function __init__()
    Base.Experimental.register_error_hint(client_hint, MethodError)
end


# Handlers
# --------
#
# A session runs a request through a pipeline of handlers, each a function from a request to an outcome.
# Inside the pipeline an outcome is a value, `Union{Response, Exception}`, so retries and redirects inspect it rather than catch it.
# `Checked` is the edge where a failed outcome becomes a thrown error.

abstract type Handler end

struct Transport{C <: Client} <: Handler
    client::C
    timeouts::Timeouts
end
(h::Transport)(r::Request) = attempt(h.client, h.timeouts, r)

struct Following{R <: Redirects, H} <: Handler
    redirects::R
    next::H
end
(h::Following)(r::Request) = follow(h, r, h.next(r), h.redirects.limit)

follow(h, r, o::Exception, n) = o
function follow(h, r, o::Response, n)
    isredirect(o) || return o
    to = resolve(r.url, header(o, "Location"))
    n == 0 && return RedirectError("more than $(h.redirects.limit) redirects from $(r.url)")
    allowed(h.redirects.scheme, r.url, to) || return RedirectError("refused a redirect from $(r.url) to $to")
    next = redirected(r, o.status, to)
    return follow(h, next, h.next(next), n - 1)
end

scheme(u) = lowercase(URI(u).scheme)

allowed(::AnyScheme, from, to) = true
allowed(::SameScheme, from, to) = scheme(to) == scheme(from) || scheme(to) == "https"

# The URL a `Location` refers to, relative to `base`, as RFC 3986 says.
resolve(base, loc) = string(resolvereference(base, loc))

# 303, and 301 or 302 after anything but GET or HEAD, continue as GET without a body, as browsers do.
function redirected(r::Request, status, to)
    asget = status == 303 || (status in (301, 302) && !(r.method in ("GET", "HEAD")))
    return asget ? with(r; method = "GET", url = to, query = Pairs(), body = UInt8[]) : with(r; url = to, query = Pairs())
end

struct Throttled{H} <: Handler
    limiter::Limiter
    next::H
end
(h::Throttled)(r::Request) = (throttle(h.limiter); h.next(r))

struct Retrying{R <: Retry, H} <: Handler
    retry::R
    next::H
end
(h::Retrying)(r::Request) = foldl((_, o) -> o, Attempts(h.retry, h.next, r); init = nothing)

retryable(p::Retry, o::Response) = o.status in p.statuses
retryable(::Retry, ::RedirectError) = false
retryable(::Retry, ::Exception) = true

delay(p::Retry, n, o::Response) = something(tryparse(Float64, header(o, "Retry-After")), backoff(p.backoff, n))
delay(p::Retry, n, o) = backoff(p.backoff, n)

# The outcomes of the attempts at one request: it ends after an outcome that is not retried, or after the last try.
struct Attempts{R <: Retry, H, Q <: Request}
    retry::R
    next::H
    request::Q
end
Base.IteratorSize(::Type{<:Attempts}) = Base.SizeUnknown()
Base.eltype(::Type{<:Attempts}) = Union{Response, Exception}
Base.iterate(a::Attempts) = outcome(a, 1)
function Base.iterate(a::Attempts, (n, previous))
    n <= a.retry.tries && retryable(a.retry, previous) || return nothing
    wait = delay(a.retry, n - 1, previous)
    wait > 0 && sleep(wait)
    return outcome(a, n)
end
outcome(a::Attempts, n) = (o = a.next(a.request); (o, (n + 1, o)))

struct Checked{H} <: Handler
    redact::Redact
    next::H
end
(h::Checked)(r::Request) = settle(h.redact, r, h.next(r))

function settle(x::Redact, r, o::Response)
    ok(o) && return o
    snippet = first(text(o), 200)
    throw(StatusError(o, mask(x, o.request, "HTTP $(o.status) from $(url(o.request))" * (isempty(snippet) ? "" : ": $snippet"))))
end
settle(x::Redact, r, e::RedirectError) = throw(RedirectError(mask(x, r, e.message)))
settle(x::Redact, r, e::Exception) = throw(TransportError(mask(x, r, "$(r.method) $(url(r)) failed: " * sprint(showerror, e)), e))

struct Authorised{A, H} <: Handler
    auth::A
    next::H
end
(h::Authorised{QueryKey})(r::Request) = h.next(with(r; query = [r.query; h.auth.name => h.auth.key]))

# Each stage takes the next handler; a policy that does nothing adds no stage.
authorised(::NoAuth) = identity
authorised(a::QueryKey) = next -> Authorised(a, next)
checked(x::Redact) = next -> Checked(x, next)
retrying(::NoRetry) = identity
retrying(p::Retry) = next -> Retrying(p, next)
throttled(::NoLimiter) = identity
throttled(l::Limiter) = next -> Throttled(l, next)
following(::NoRedirects) = identity
following(p::Redirects) = next -> Following(p, next)


# Sessions
# --------

"""
    Session(client, service; policies...)

A session sends requests to one `service` with `client`, under the service's policies.
`service` is the service's configuration, such as `EUtilsAPI(api_key = ...)`.
The keywords override the service's policies: `timeouts`, `retries`, `redirects`, `ratelimit`, `redact` and `auth`.

Each session has its own rate limiter.
Copies of a session share it, so a session used in two places keeps to one budget, as services that count requests per IP address or per key expect.

A session runs requests to its service, and workflows of them: `run(s, d)`, or `d |> s`.
Sessions combine as a vector, or a tuple, which runs each request with the first session for its service:

    ss = [Session(DownloadsClient(), EUtilsAPI()), Session(HTTPClient(), UMLSAPI(apikey = key))]
    run(ss, d)
"""
struct Session{S <: Service, C <: Client, P <: NamedTuple, L}
    service::S
    client::C
    overrides::P
    limiter::L
end

Session(client::Client, service::Service; policies...) = assemble(service, client, values(policies), nothing)

# A session whose limiter is `old` when the rate allows it, and a new one otherwise.
assemble(service, client, overrides, old) = Session(service, client, overrides, renew(old, settings(service, overrides).ratelimit))

settings(s::Session) = settings(s.service, s.overrides)

function Base.show(io::IO, s::Session)
    print(io, "Session(", s.client, ", ", s.service)
    isempty(s.overrides) || print(io, "; ", join(map(k -> "$k = $(s.overrides[k])", keys(s.overrides)), ", "))
    return print(io, ")")
end

"Sessions combined: a vector or a tuple of sessions, each for one service."
const Combined = Union{AbstractVector{<:Session}, Tuple{Vararg{Session}}}

"Something that runs requests: a session, or sessions combined."
const Runner = Union{Session, Combined}

# The first of the sessions `ss` for service `S`.
function session(ss::Combined, ::Type{S}) where {S <: Service}
    found = Iterators.filter(s -> s isa Session{S}, ss)
    isempty(found) && throw(ArgumentError("there is no session for $S; add one, such as `Session(client, $S())`"))
    return first(found)
end

"""
    configuration(s, S::Type{<:Service})

The configuration of service `S`, such as its credentials, in the session `s` or the first session for `S` among sessions combined.
"""
configuration(s::Session{S}, ::Type{T}) where {S <: Service, T <: Service} = S === T ? s.service : elsewhere(s, T)
configuration(ss::Combined, ::Type{S}) where {S <: Service} = configuration(session(ss, S), S)

elsewhere(::Session{S}, ::Type{T}) where {S, T} =
    throw(ArgumentError("this session is for $S, not $T; combine sessions in a vector to run requests to several services"))

"""
    configure(s::Session; client, policies...)
    configure(s::Session{S}, service::S; policies...)
    configure(ss, S::Type{<:Service}; client, policies...)
    configure(ss, service::Service; policies...)

Return a new session with the client, the policies or the service's configuration replaced; `s` is unchanged.
With sessions combined, `ss`, return them with every session for the service configured.

The policies are `timeouts`, `retries`, `redirects`, `ratelimit`, `redact` and `auth`.
Policies set before are kept, and the others follow from the service, so a new E-utilities key raises its rate limit:

    s = configure(s, EUtilsAPI(api_key = ENV["NCBI_API_KEY"]))
    s = configure(s; timeouts = Timeouts(10, 300))
    ss = configure(ss, GGGenomeAPI; client = HTTPClient())

A session keeps its rate limiter, and the time of its next free slot, unless its rate limit changes.
"""
configure(s::Session; client::Client = s.client, policies...) =
    assemble(s.service, client, merge(s.overrides, values(policies)), s.limiter)
configure(s::Session{S}, service::S; policies...) where {S <: Service} =
    assemble(service, s.client, merge(s.overrides, values(policies)), s.limiter)
configure(ss::Combined, ::Type{S}; kwargs...) where {S <: Service} =
    map(s -> s isa Session{S} ? configure(s; kwargs...) : s, ss)
configure(ss::Combined, service::S; policies...) where {S <: Service} =
    map(s -> s isa Session{S} ? configure(s, service; policies...) : s, ss)

"""
    handler(s::Session)

The pipeline that runs the requests of `s`: authorise, check, retry, throttle, follow redirects, send.
"""
function handler(s::Session)
    c = settings(s)
    stages = authorised(c.auth) ∘ checked(c.redact) ∘ retrying(c.retries) ∘ throttled(s.limiter) ∘ following(c.redirects)
    return stages(Transport(s.client, c.timeouts))
end


# Running
# -------

"""
    run(s, x)

Run `x` with the session `s`, or with sessions combined, and return its result.
`x` is a [`Request`](@ref), a [`Workflow`](@ref), or anything with a `Request(x)` method, such as an endpoint type.
A request's result is its [`Response`](@ref).
A response with a status of 400 or more throws a [`StatusError`](@ref), and a failure to send throws a [`TransportError`](@ref), after the service's retries.
"""
Base.run(ss::Runner, x) = interpret(ss, x)

# `run` has one method, and `interpret` dispatches on what is run, so no method of `run` is ambiguous with another.
# The service types are compared, not matched by dispatch: a diagonal method on `(Session{S}, Request{S})` does not win over `(Session, Request)`.
interpret(s::Session{S}, r::Request{T}) where {S, T} = S === T ? handler(s)(r) : elsewhere(s, T)
interpret(ss::Combined, r::Request{S}) where {S} = interpret(session(ss, S), r)
interpret(ss, w::Workflow) = w.f(ss)
interpret(ss, x) = interpret(ss, Request(x)::Request)

(s::Session)(x) = run(s, x)

end # module Sessions
