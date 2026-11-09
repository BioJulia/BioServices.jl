using BioServices: escape, form, url

@testset "URLs" begin
    @testset "escape" begin
        @test escape("+/ é?#&=:") == "%2B%2F%20%C3%A9%3F%23%26%3D%3A"
        @test escape("AZaz09-_.") == "AZaz09-_."
        @test escape(9606) == "9606"
    end

    @testset "form" begin
        @test form(["service" => "http://x.org", "b" => "1 2"]) == "service=http%3A%2F%2Fx.org&b=1%202"
        @test form(Dict(:term => "a&b")) == "term=a%26b"
        @test form((db = "pubmed", retmax = 5)) == "db=pubmed&retmax=5"
        @test form(["db" => "pubmed", "WebEnv" => nothing]) == "db=pubmed"   # a `nothing` value is left out
        @test form(Pair{String, String}[]) == ""
    end

    @testset "url" begin
        base = "https://example.org/api/"
        @test url(base) == base
        @test url(base, "proteins", "P0 8") == "https://example.org/api/proteins/P0%208"
        @test url(base, "hg38", 0, "+", "ACGT.txt") == "https://example.org/api/hg38/0/%2B/ACGT.txt"
        @test url(base * "search"; query = ["q" => "a b", "n" => 1]) == "https://example.org/api/search?q=a%20b&n=1"
        @test url("https://example.org/?x=1"; query = ["y" => 2]) == "https://example.org/?x=1&y=2"
        @test url(base * "search"; query = Dict{Symbol, Any}()) == "https://example.org/api/search"
        # A query value is encoded once, so an EBI `upid` with a space is sent as %20, not %2520.
        @test url(base * "proteomes"; query = Dict(:upid => "UP 1")) == "https://example.org/api/proteomes?upid=UP%201"
    end
end
