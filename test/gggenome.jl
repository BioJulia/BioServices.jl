
@testset "GGGenome" begin
    @testset "gggsearch" begin
        query = "TTCATTGACAACATT"
        res = gggsearch(query, db="felCat5", format = "html")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/html")
        @test occursin(Regex("query="*query), String(res.body))

        res = gggsearch(query, db="felCat5", format = "txt", output = "toString")
        @test typeof(res) == String

        res = gggsearch(query, db="felCat5", format = "txt", output = "extractTopHit")
        @test typeof(res) == String
    end

    @testset "gggdbs" begin
       @test  length(gggdbs()) > 0
    end

end
