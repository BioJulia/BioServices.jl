@testset "bioDBnet" begin
    @testset "db2db" begin
        # test #1 - json
        res = bioDBnet.db2db(input="DrugBankDrugId",
            outputs = ["PubChemId","KeggDrugId"],values = ["DB00316","DB00945"],
            taxonid = "9606", rettype="json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - xml
        res = bioDBnet.db2db(input = "DrugBankDrugId",
            outputs = ["PubChemId","KeggDrugId"],values = ["DB00316","DB00945"],
            taxonid = "9606", rettype = "xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "dbwalk" begin
        # test #1 - json
        res = bioDBnet.dbwalk(values=["DB00316","DB00945"],
            db_path = ["DrugBankDrugId","PubChemId","KeggDrugId"],
            taxonid = "9606", rettype = "json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - xml
        res = bioDBnet.dbwalk(values = ["DB00316","DB00945"],
            db_path = ["DrugBankDrugId","PubChemId","KeggDrugId"],
            taxonid = "9606", rettype = "xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"

    end

    @testset "dbreport" begin
        # test #1 - json
        res = bioDBnet.dbreport(input="DrugBankDrugId",
            values = ["DB00316","DB00945"], taxonid = "9606",
            rettype = "json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - xml
        res = bioDBnet.dbreport(input="DrugBankDrugId",
            values = ["DB00316","DB00945"], taxonid = "9606",
            rettype = "xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "dbfind" begin
        #test1 - json
        res = bioDBnet.dbfind(values = ["DB00316","DB00945"],
            output = "KeggDrugId", taxonid = "9606", rettype = "json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - xml
        res = bioDBnet.dbfind(values = ["DB00316","DB00945"],
            output = "KeggDrugId", taxonid = "9606", rettype = "xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "db_ortho" begin
        #test #1 - json
        res = bioDBnet.db_ortho(input="GeneId",
            values=["7157","1432"], output = "GeneId",
            in_taxon="9606", out_taxon="10090", rettype="json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - xml
        res = bioDBnet.db_ortho(input="GeneId",
            values=["7157","1432"], output = "GeneId",
            in_taxon="9606", out_taxon="10090", rettype="xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "db_annot" begin
        #test #1 - json
        res = bioDBnet.db_annot(values=["DB00316","DB00945"],
                                annotations=["Drugs"], rettype="json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - xml
        res = bioDBnet.db_annot(values=["DB00316","DB00945"],
                                annotations=["Drugs"], rettype="xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end

    @testset "get_inputs" begin
        #test #1 - JSON
        res = bioDBnet.get_inputs(rettype="json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Dict{String, Any})

        sleep(0.2)
        # test #2 - XML
        res = bioDBnet.get_inputs(rettype="xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body) != "ERROR"
    end

    @testset "get_pathways" begin
        #test #1 - JSON
        res = bioDBnet.get_pathways(taxonid = "9606", rettype="json")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/json")
        body = JSON.parse(String(res.body))
        @test isa(body, Array{Any,1})
        @test isa(body[1], Dict{String, Any})

        sleep(0.2)
        # test #2 - XML
        res = bioDBnet.get_pathways(taxonid = "9606", rettype="xml")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "application/xml")
        body = XMLDict.parse_xml(String(res.body))
        @test isa(body, XMLDict.XMLDictElement)
        @test first(body)[1] != "ERROR"
    end
end
