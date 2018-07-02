
@testset "GGGenome" begin
    @testset "gggenome" begin
        query = "GTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGA"
        res = gggenome(query = query, db="mm10", format = "txt")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "gggenome_dblist" begin
       @test  length(gggenome_dblist()) > 0
    end
end
