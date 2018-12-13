
@testset "EUtils" begin

    @testset "einfo" begin
        sleep(0.3)
        res = einfo(db="pubmed")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "esearch" begin
        sleep(0.3)
        res = esearch(db="pubmed", term="""(Asthma[MeSH Major Topic]) AND
                                        ("1/1/2018"[Date - Publication] :
                                        "3000"[Date - Publication])""")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "epost" begin
        sleep(0.3)
        ctx = Dict()
        res = epost(ctx, db="protein", id="NP_005537")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test haskey(ctx, :WebEnv)
        @test haskey(ctx, :query_key)
    end

    @testset "esummary" begin
        # esummary doesn't seem to support accession numbers
        sleep(0.3)
        res = esummary(db="protein", id="15718680,157427902,119703751")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"

        sleep(0.3)
        res = esummary(db="protein", id=["15718680", "157427902", "119703751"])
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"

        # esearch then esummary
        sleep(0.3)
        query = "asthma[mesh] AND leukotrienes[mesh] AND 2009[pdat]"
        ctx = Dict()
        res = esearch(ctx, db="pubmed", term=query, usehistory=true, retmode="xml")
        @test res.status == 200
        sleep(0.3)
        res = esummary(ctx, db="pubmed")
        @test res.status == 200

        sleep(0.3)
        ctx = Dict()
        res = esearch(ctx, db="pubmed", term=query, usehistory=true, retmode="json")
        @test res.status == 200
        sleep(0.3)
        res = esummary(ctx, db="pubmed")
        @test res.status == 200
    end


    @testset "efetch" begin
        sleep(0.3)
        res = efetch(db="nuccore", id="NM_001178.5", retmode="xml", idtype="acc")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        @test isa(parse_xml(String(res.body)), XMLDict.XMLDictElement)

        # epost then efetch
        sleep(0.3)
        ctx = Dict()
        res = epost(ctx, db="protein", id="NP_005537")
        @test res.status == 200
        sleep(0.3)
        res = efetch(ctx, db="protein", retmode="xml")
        @test res.status == 200

        # esearch then efeth for large number of ids
        retmax = 1000
        search_term = """(Asthma[MeSH Major Topic])
                        AND ("1/1/2018"[Date - Publication] :
                        "3000"[Date - Publication])"""
        sleep(0.3)
        res = esearch(db = "pubmed", term = search_term,
        retstart = 0, retmax = retmax, tool = "BioJulia")

        #convert xml to dictionary
        esearch_dict = parse_xml(String(res.body))

        #get the list of ids and perfom a fetch
        ids = [parse(Int64, id_node) for id_node in esearch_dict["IdList"]["Id"]]

        sleep(0.3)
        res = efetch(db = "pubmed", tool = "BioJulia", retmode = "xml", rettype = "null", id = ids)
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")

        body = parse_xml(String(res.body))

        @test haskey(body, "PubmedArticle")
        @test length(body["PubmedArticle"]) == retmax

    end

    @testset "elink" begin
        sleep(0.3)
        res = elink(dbfrom="protein", db="gene", id="NM_001178.5")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        @test isa(parse_xml(String(res.body)), XMLDict.XMLDictElement)
    end

    @testset "egquery" begin
        sleep(0.3)
        res = egquery(term="""(Asthma[MeSH Major Topic]) AND
                              ("1/1/2018"[Date - Publication] :
                              "3000"[Date - Publication])""")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        @test isa(parse_xml(String(res.body)), XMLDict.XMLDictElement)
    end

    @testset "espell" begin
        sleep(0.3)
        res = espell(db="pmc", term="fiberblast cell grwth")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        replaced_spell = body["SpelledQuery"]["Replaced"][2]
        @test replaced_spell == "growth"
    end

    @testset "ecitmatch" begin
        sleep(0.3)
        res = ecitmatch(
            db="pubmed",
            retmode="xml",
            bdata="proc natl acad sci u s a|1991|88|3248|mann bj|Art1|")
        @test res.status == 200
        # ECitMatch is mysterious: it returns a plain text data even though it
        # requires retmode="xml".
        # @show res.headers["Content-Type"]
    end
end
