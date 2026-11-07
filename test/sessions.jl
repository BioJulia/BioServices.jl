# Offline tests of sessions, against a client that replays scripted outcomes.

import BioServices.Sessions as S
using BioServices.Sessions
using BioServices.UMLS: get_tgt, get_cui, search_umls, search_pages

# A client that answers each request with the next scripted outcome: a status, a `(status, headers)` pair, an exception, or a body.
struct Replay <: S.Client
    script::Vector{Any}
    sent::Vector{S.Request}
    Replay(script...) = new(collect(Any, script), S.Request[])
end

reply(r, status::Int) = S.Response(status, Pair{String, String}[], Vector{UInt8}("body $status"), r)
reply(r, (status, headers)::Tuple) = S.Response(status, headers, Vector{UInt8}("body $status"), r)
reply(r, body::String) = S.Response(200, Pair{String, String}[], Vector{UInt8}(body), r)
reply(r, e::Exception) = e
S.perform(c::Replay, t::S.Timeouts, r::S.Request) = (push!(c.sent, r); reply(r, popfirst!(c.script)))

# A session whose retries do not wait.
quick(c, svc; kwargs...) = Session(c, svc; retries = S.Retry(S.retries(svc).tries, S.retries(svc).statuses, Fixed(0)), kwargs...)

# An endpoint type of another package, as a generated client defines one per operation, and a service of another package.
Base.@kwdef struct ProteinsByAccession
    accession::String
    format::Union{Nothing, String} = nothing
end
S.Request(e::ProteinsByAccession) =
    ebi("proteins/" * S.escapeuri(e.accession); query = filter(!isnothing ∘ last, ["format" => e.format]))
Base.@kwdef struct Page
    n::Int
end
S.Request(p::Page) = ebi("proteins"; query = ["offset" => p.n])
struct Unrunnable end
struct Elsewhere <: S.Service end

ebi(path = "proteins/P1"; kwargs...) = Request{EBIProteinsAPI}("GET", "https://www.ebi.ac.uk/proteins/api/$path"; kwargs...)
umls(path = "x") = Request{UMLSAPI}("GET", "https://uts-ws.nlm.nih.gov/rest/$path")

@testset "Sessions" begin
    @testset "requests" begin
        r = Request{EUtilsAPI}("GET", "https://example.org/e"; query = Dict(:term => "a b&c", :db => "pubmed"))
        @test S.service(r) === EUtilsAPI
        @test S.url(r) in ("https://example.org/e?term=a%20b%26c&db=pubmed", "https://example.org/e?db=pubmed&term=a%20b%26c")
        @test S.url(Request{Generic}("GET", "https://example.org/?x=1"; query = ["y" => 2])) == "https://example.org/?x=1&y=2"
        # `url` and `form` are tested in `common.jl`.
        @test Request{Generic}("POST", "https://example.org"; body = "ab").body == UInt8['a', 'b']
    end

    @testset "a session runs requests to its service" begin
        c = Replay(200, 200)
        s = Session(c, EBIProteinsAPI())
        @test run(s, ebi()) isa S.Response{EBIProteinsAPI}
        @test (ebi() |> s).status == 200
        @test_throws ArgumentError run(s, umls())   # a request to another service
        @test length(c.sent) == 2
        @test configuration(Session(c, EUtilsAPI(api_key = "k")), EUtilsAPI).api_key == "k"
        @test_throws ArgumentError configuration(s, UMLSAPI)
        @test !occursin("k\"", repr(Session(c, EUtilsAPI(api_key = "k"))))   # keys are masked when shown
    end

    @testset "sessions combine" begin
        a, b = Replay(200, 200), Replay(200)
        ss = [Session(a, EBIProteinsAPI()), Session(b, UMLSAPI(apikey = "u"))]
        run(ss, ebi()); run(ss, umls()); run(ss, ebi())
        @test length(a.sent) == 2 && length(b.sent) == 1   # each session keeps its own client
        @test configuration(ss, UMLSAPI).apikey == "u"
        @test_throws ArgumentError run(ss, Request{EUtilsAPI}("GET", "https://example.org"))
        # The first session for a service wins, so prepending one overrides it.
        o = Replay(200)
        run([Session(o, EBIProteinsAPI()); ss], ebi())
        @test length(o.sent) == 1 && length(a.sent) == 2
        # A tuple combines sessions too.
        @test run((Session(Replay(200), GGGenomeAPI()),), Request{GGGenomeAPI}("GET", "https://gggenome.dbcls.jp/x")).status == 200
        # A service of another package needs only a session.
        @test run([Session(Replay(200), Elsewhere())], Request{Elsewhere}("GET", "https://example.org")).status == 200
    end

    @testset "workflows" begin
        c = Replay(200, 200, 200)
        s = Session(c, EBIProteinsAPI())
        @test run(s, map(r -> r.status, ebi())) == 200
        # A request built from an earlier result runs after it.
        w = Workflow() do ss
            res = run(ss, ebi())
            run(ss, ebi("features/$(res.status)"))
        end
        @test run(s, w).request.url == "https://www.ebi.ac.uk/proteins/api/features/200"
        # Nothing runs until the workflow does.
        calls = Ref(0)
        lazy = Workflow(_ -> calls[] += 1)
        @test calls[] == 0 && run(s, lazy) == 1 && run(s, lazy) == 2
        @test run(s, Workflow(ss -> configuration(ss, EBIProteinsAPI))) == EBIProteinsAPI()
    end

    @testset "paged sequences" begin
        s = Session(Replay(), Generic())
        @test run(s, map(collect, unfold(n -> Workflow(_ -> n), n -> n > 3))) == [1, 2, 3]
        @test first(run(s, unfold(n -> Workflow(_ -> n), n -> false)), 5) == 1:5   # lazy: an endless sequence
    end

    @testset "UMLS workflows" begin
        tgt = "https://utslogin.nlm.nih.gov/cas/v1/tickets/TGT-1"
        page(ui) = """{"result": {"results": [{"ui": "$ui"}]}}"""
        c = Replay("ST-1", page("C1"), "ST-2", page("NONE"))
        ss = [Session(c, UMLSAPI())]
        @test map(p -> p["result"]["results"][1]["ui"], run(ss, search_umls(tgt, Dict("string" => "obesity")))) == ["C1"]
        @test length(c.sent) == 4 && ("pageNumber" => "1") in c.sent[2].query && ("ticket" => "ST-1") in c.sent[2].query
        # Only the pages taken are requested.
        c = Replay("ST-1", page("C1"))
        @test first(run(Session(c, UMLSAPI()), search_pages(tgt, Dict("string" => "obesity"))))["result"]["results"][1]["ui"] == "C1"
        @test length(c.sent) == 2
        c = Replay("ST-1", """{"result": {"name": "x"}}""")
        @test run(Session(c, UMLSAPI()), get_cui(tgt, "C0028754"))["result"]["name"] == "x"
        @test c.sent[2].query == ["ticket" => "ST-1"]
        # Without credentials, `get_tgt` reads them from the session.
        @test_throws ErrorException run(Session(Replay(), UMLSAPI()), get_tgt(force_new = true, tgt_file = tempname()))
    end

    @testset "endpoint types run through Request" begin
        c = Replay(fill(200, 6)...)
        s = Session(c, EBIProteinsAPI())
        @test run(s, ProteinsByAccession(accession = "P08069")).status == 200
        @test only(c.sent).url == "https://www.ebi.ac.uk/proteins/api/proteins/P08069" && isempty(only(c.sent).query)
        @test S.url(Request(ProteinsByAccession(accession = "P0 8", format = "json"))) ==
            "https://www.ebi.ac.uk/proteins/api/proteins/P0%208?format=json"
        @test run([s], ProteinsByAccession(accession = "P1")).status == 200   # combined sessions too
        @test run(s, map(r -> r.status, Request(ProteinsByAccession(accession = "P1")))) == 200
        # A paged sequence of endpoints.
        @test map(r -> r.request.query, run(s, map(collect, unfold(Page, r -> r.request.query == ["offset" => "3"])))) ==
            [["offset" => "1"], ["offset" => "2"]]
        @test_throws MethodError run(s, Unrunnable())
    end

    @testset "retries" begin
        c = Replay(503, 429, 200)
        @test run(quick(c, EBIProteinsAPI()), ebi()).status == 200
        @test length(c.sent) == 3
        c = Replay(503, 503, 503, 503)
        @test_throws StatusError run(quick(c, EBIProteinsAPI()), ebi())
        @test length(c.sent) == 4   # EBI Proteins makes four tries
        c = Replay(401, 200)
        @test_throws StatusError run(quick(c, UMLSAPI()), umls())
        @test length(c.sent) == 1   # 401 is not retried
        c = Replay(Base.IOError("reset", 0), 200)
        @test run(quick(c, EBIProteinsAPI()), ebi()).status == 200
        c = Replay(503, 200)
        @test_throws StatusError run(Session(c, EBIProteinsAPI(); retries = NoRetry()), ebi())
        # Retry-After replaces the backoff.
        c = Replay((429, ["Retry-After" => "0"]), 200)
        @test run(Session(c, EBIProteinsAPI(); retries = Retry(2, (429,), Fixed(60))), ebi()).status == 200
        e = try
            run(quick(Replay(fill(ArgumentError("no route"), 4)...), EBIProteinsAPI()), ebi())
        catch err
            err
        end
        @test e isa TransportError && occursin("no route", sprint(showerror, e))
    end

    @testset "redirects" begin
        moved(to) = (301, ["Location" => to])
        c = Replay(moved("/proteins/api/proteins/P2"), 200)
        res = run(quick(c, EBIProteinsAPI()), ebi())
        @test res.request.url == "https://www.ebi.ac.uk/proteins/api/proteins/P2"
        # Locations resolve against the request's URL, as RFC 3986 says.
        base = "https://example.org/a/b/c"
        for (loc, to) in (
                "/abs" => "https://example.org/abs", "rel" => "https://example.org/a/b/rel",
                "?q=1" => "https://example.org/a/b/c?q=1", "//other.org/p" => "https://other.org/p",
                "../up" => "https://example.org/a/up", "https://x.org/z" => "https://x.org/z",
            )
            c = Replay(moved(loc), 200)
            @test run(quick(c, Generic()), Request{Generic}("GET", base)).request.url == to
        end
        # GGGenome's redirects to plain http are refused.
        c = Replay(moved("http://gggenome.dbcls.jp/hg38/ACGT.json"))
        @test_throws RedirectError run(quick(c, GGGenomeAPI()), Request{GGGenomeAPI}("GET", "https://gggenome.dbcls.jp/hg38/0/ACGT.json"))
        c = Replay(moved("http://example.org/b"), 200)
        @test run(quick(c, Generic()), Request{Generic}("GET", "https://example.org/a")).status == 200
        c = Replay(fill(moved("/again"), 7)...)
        @test_throws RedirectError run(quick(c, EBIProteinsAPI()), ebi())
        @test length(c.sent) == 6   # the request and five redirects
        c = Replay((303, ["Location" => "/done"]), 200)
        run(quick(c, Generic()), Request{Generic}("POST", "https://example.org/form"; body = "x=1"))
        @test c.sent[2].method == "GET" && isempty(c.sent[2].body)
        c = Replay(moved("/elsewhere"))
        @test run(Session(c, EBIProteinsAPI(); redirects = NoRedirects()), ebi()).status == 301
    end

    @testset "one limiter per session" begin
        c = Replay(fill(200, 12)...)
        ss = [Session(c, UMLSAPI(); ratelimit = RateLimit(10)), Session(c, EBIProteinsAPI())]
        t = @elapsed foreach(_ -> run(ss, umls()), 1:6)
        @test t >= 0.45   # six requests at ten per second: five gaps of 0.1 s
        t = @elapsed foreach(_ -> run(ss, ebi()), 1:6)
        @test t < 0.1     # the EBI Proteins session has its own limiter, and no limit
        s = first(ss)
        @test Session(c, UMLSAPI()).limiter !== s.limiter   # two sessions, two limiters
        # A limiter survives configuration that keeps its rate, and copies of a session share it.
        @test configure(s; timeouts = Timeouts(1, 1)).limiter === s.limiter
        @test configure(s; client = Replay()).limiter === s.limiter
        @test configure(s; ratelimit = RateLimit(5)).limiter !== s.limiter
        @test first([s, s]).limiter === last([s, s]).limiter
    end

    @testset "E-utilities key" begin
        @test S.rate(Session(Replay(), EUtilsAPI()).limiter) == RateLimit(3)
        c = Replay(200, (400, Pair{String, String}[]))
        k = configure(Session(c, EUtilsAPI()), EUtilsAPI(api_key = "SECRET"))
        @test S.rate(k.limiter) == RateLimit(10)
        e = Request{EUtilsAPI}("GET", "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/einfo.fcgi"; query = ["db" => "pubmed"])
        run(k, e)
        @test last(c.sent).query == ["db" => "pubmed", "api_key" => "SECRET"]
        err = try
            run(k, e)
        catch x
            x
        end
        @test err isa StatusError && !occursin("SECRET", sprint(showerror, err)) && occursin("api_key=***", sprint(showerror, err))
    end

    @testset "configure" begin
        s = Session(Replay(), GGGenomeAPI())
        t = configure(s; timeouts = Timeouts(1, 2))
        @test S.settings(t).timeouts == Timeouts(1, 2)
        @test S.settings(s).timeouts == Timeouts(10, 60)   # unchanged
        # Overrides are kept when the service's configuration changes.
        u = configure(Session(Replay(), EUtilsAPI(); timeouts = Timeouts(1, 2)), EUtilsAPI(api_key = "k"))
        @test S.settings(u).timeouts == Timeouts(1, 2) && u.service.api_key == "k"
        @test_throws ArgumentError Session(Replay(), GGGenomeAPI(); timeout = 3)
        @test_throws ArgumentError configure(s; timeout = 3)
        # Configuring combined sessions configures every session for the service.
        ss = [s, Session(Replay(), EUtilsAPI())]
        tt = configure(ss, GGGenomeAPI; timeouts = Timeouts(1, 2))
        @test S.settings(first(tt)).timeouts == Timeouts(1, 2) && last(tt) === last(ss)
        @test configuration(configure(ss, EUtilsAPI(api_key = "k")), EUtilsAPI).api_key == "k"
        @test configuration(ss, EUtilsAPI).api_key === nothing   # unchanged
    end

    @testset "missing client package" begin
        code = """
        using BioServices.Sessions
        try
            run(Session(HTTPClient(), Generic()), Request{Generic}("GET", "https://example.org"))
        catch e
            print(sprint(showerror, e))
        end
        """
        out = read(`$(Base.julia_cmd()) --project=$(Base.active_project()) --startup-file=no -e $code`, String)
        @test occursin("HTTPClient needs HTTP; load it with `using HTTP`.", out)
    end
end
