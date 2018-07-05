
@testset "GGGenome" begin
    @testset "gggsearch" begin
        query = "GTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGA"
        res = gggsearch(query, db = "mm10", format = "txt")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "gggdbs" begin
       @test  length(gggdbs()) > 0
    end
end
