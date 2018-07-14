
@testset "GGGenome" begin
    @testset "gggsearch" begin
        query = "TTCATTGACAACATT"
        res = gggsearch(query, db="felCat5", format = "txt")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"

        res = gggsearch(query, db="felCat5", format = "txt", output = "toString")
        @test typeof(res) == String

        res = gggsearch(query, db="felCat5", format = "txt", output = "extractTopHit")
        @test typeof(res) == String
    end

    @testset "gggdbs" begin
       @test  length(gggdbs()) > 0
    end

end
