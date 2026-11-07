@testset "EUtils" begin

    @testset "einfo" begin
        res = run(s, einfo(db = "pubmed"))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "esearch" begin
        res = run(
            s, esearch(
                db = "pubmed", term = """(Asthma[MeSH Major Topic]) AND
                ("1/1/2018"[Date - Publication] :
                "3000"[Date - Publication])"""
            )
        )
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "epost" begin
        ctx = Dict()
        res = run(s, epost(ctx, db = "protein", id = "NP_005537"))
        ctx = context(ctx, res)
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test haskey(ctx, :WebEnv)
        @test haskey(ctx, :query_key)
    end

    @testset "esummary" begin
        # esummary doesn't seem to support accession numbers
        res = run(s, esummary(db = "protein", id = "15718680,157427902,119703751"))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"

        res = run(s, esummary(db = "protein", id = ["15718680", "157427902", "119703751"]))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"

        # esearch then esummary
        query = "asthma[mesh] AND leukotrienes[mesh] AND 2009[pdat]"
        ctx = Dict()
        res = run(s, esearch(ctx, db = "pubmed", term = query, usehistory = true, retmode = "xml"))
        ctx = context(ctx, res)
        @test res.status == 200
        res = run(s, esummary(ctx, db = "pubmed"))
        @test res.status == 200

        ctx = Dict()
        res = run(s, esearch(ctx, db = "pubmed", term = query, usehistory = true, retmode = "json"))
        ctx = context(ctx, res)
        @test res.status == 200
        res = run(s, esummary(ctx, db = "pubmed"))
        @test res.status == 200
    end


    @testset "efetch" begin
        res = run(s, efetch(db = "nuccore", id = "NM_001178.5", retmode = "xml", idtype = "acc"))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        @test isa(parse_xml(String(res.body)), XMLDict.XMLDictElement)

        # epost then efetch
        ctx = Dict()
        res = run(s, epost(ctx, db = "protein", id = "NP_005537"))
        ctx = context(ctx, res)
        @test res.status == 200
        res = run(s, efetch(ctx, db = "protein", retmode = "xml"))
        @test res.status == 200

        # esearch then efeth for large number of ids
        retmax = 1000
        search_term = """(Asthma[MeSH Major Topic])
        AND (("2018/01/01"[Date - Publication] : 
        "3000"[Date - Publication]))"""
        res = run(
            s, esearch(
                db = "pubmed", term = search_term,
                retstart = 0, retmax = retmax, tool = "BioJulia"
            )
        )

        #convert xml to dictionary
        esearch_dict = parse_xml(String(res.body))

        #get the list of ids and perfom a fetch
        ids = [parse(Int64, id_node) for id_node in esearch_dict["IdList"]["Id"]]

        res = run(s, efetch(db = "pubmed", tool = "BioJulia", retmode = "xml", rettype = "null", id = ids))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")

        body = parse_xml(String(res.body))

        @test haskey(body, "PubmedArticle")
        @test length(body["PubmedArticle"]) == retmax

    end

    @testset "elink" begin
        res = run(s, elink(dbfrom = "protein", db = "gene", id = "NM_001178.5"))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        @test isa(parse_xml(String(res.body)), XMLDict.XMLDictElement)
    end

    @testset "egquery" begin
        # egquery.fcgi redirects to ext-http-eutils.linkerd.ncbi.nlm.nih.gov, which does not resolve
        @test_broken run(
            s, egquery(
                term = """(Asthma[MeSH Major Topic]) AND
                (("2018/01/01"[Date - Publication] : 
                "3000"[Date - Publication]))"""
            )
        ).status == 200
    end

    @testset "espell" begin
        res = run(s, espell(db = "pubmed", term = "fiberblast cell grwth"))
        @test res.status == 200
        @test startswith(header(res, "Content-Type"), "text/xml")
        body = parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        replaced_spell = body["SpelledQuery"]["Replaced"][2]
        @test replaced_spell == "growth"
    end

    @testset "ecitmatch" begin
        res = run(
            s, ecitmatch(
                db = "pubmed",
                retmode = "xml",
                bdata = "proc natl acad sci u s a|1991|88|3248|mann bj|Art1|"
            )
        )
        @test res.status == 200
        # ECitMatch is mysterious: it returns a plain text data even though it
        # requires retmode="xml".
        # @show res.headers["Content-Type"]
    end
end
