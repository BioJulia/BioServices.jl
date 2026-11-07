@testset "GGGenome" begin
    @testset "gggsearch" begin
        query = "TTCATTGACAACATT"
        res = run(s, gggsearch(query, db = "felCat5", format = "html"))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/html")
        @test occursin(Regex("query=" * query), String(res.body))

        res = run(s, gggsearch(query, db = "felCat5", format = "txt", output = "toString"))
        @test typeof(res) == String

        res = run(s, gggsearch(query, db = "felCat5", format = "txt", output = "extractTopHit"))
        @test typeof(res) == String
    end

    @testset "gggsearch url" begin
        # Each path segment is percent-encoded, so the `+` strand is sent as %2B.
        r = gggsearch("TTCATTGACAACATT", db = "felCat5", strand = "+", format = "txt")
        @test url(r) == "https://gggenome.dbcls.jp/felCat5/%2B/TTCATTGACAACATT.txt"
    end

    @testset "gggdbs" begin
        @test  length(run(s, gggdbs())) > 0
    end

end
