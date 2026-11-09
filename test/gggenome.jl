@testset "GGGenome" begin
    @testset "gggsearch" begin
        query = "TTCATTGACAACATT"
        res = gggsearch(query, db = "felCat5", format = "html")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/html")
        @test occursin(Regex("query=" * query), String(res.body))

        res = gggsearch(query, db = "felCat5", format = "txt", output = "toString")
        @test typeof(res) == String

        res = gggsearch(query, db = "felCat5", format = "txt", output = "extractTopHit")
        @test typeof(res) == String
    end

    @testset "gggsearch show_url" begin
        # Each path segment is percent-encoded, so the `+` strand is sent as %2B.
        out = mktemp() do path, io
            redirect_stdout(io) do
                gggsearch("TTCATTGACAACATT", db = "felCat5", strand = "+", format = "txt", show_url = true)
            end
            close(io)
            read(path, String)
        end
        @test chomp(out) == "https://gggenome.dbcls.jp/felCat5/0/%2B/TTCATTGACAACATT.txt"
    end

    @testset "gggdbs" begin
        @test  length(gggdbs()) > 0
    end

end
