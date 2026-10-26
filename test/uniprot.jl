@testset "UniProt" begin

    @testset "uniprotentry" begin
        res = uniprotentry("P08069", format = "fasta")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/plain")
        @test startswith(String(res.body), ">sp|P08069|IGF1R_HUMAN")

        res = uniprotentry("P08069", format = "json", fields = ["accession", "gene_names"])
        body = JSON.parse(String(res.body))
        @test body["primaryAccession"] == "P08069"
        @test body["genes"][1]["geneName"]["value"] == "IGF1R"

        res = uniprotentry(9606, dataset = "taxonomy", format = "json")
        body = JSON.parse(String(res.body))
        @test body["scientificName"] == "Homo sapiens"

        res = uniprotentry("UniRef90_P08069", dataset = "uniref", subset = "members", format = "json", size = 2)
        body = JSON.parse(String(res.body))
        @test length(body["results"]) == 2

        @test_throws HTTP.StatusError uniprotentry("NOTANACCESSION")
    end

    @testset "uniprotentries" begin
        accessions = ["P08069", "P35626"]
        res = uniprotentries(accessions, format = "list")
        @test res.status == 200
        @test split(String(res.body)) == accessions
        res = uniprotentries(join(accessions, ','), format = "list")
        @test split(String(res.body)) == accessions

        res = uniprotentries(["UniRef90_P08069"], dataset = "uniref", format = "list")
        @test split(String(res.body)) == ["UniRef90_P08069"]

        @test_throws "`dataset` must be one of" uniprotentries(accessions, dataset = "taxonomy")
    end

    @testset "uniprotsearch" begin
        res = uniprotsearch("id:T2R38_MOUSE", fields = "accession", format = "tsv")
        @test res.status == 200
        @test split(String(res.body)) == ["Entry", "Q7TQA6"]

        res = uniprotsearch("accession:P08069", fields = ["accession", "length"], format = "tsv")
        @test split(String(res.body), '\n')[2] == "P08069\t1367"

        res = uniprotsearch("human", dataset = "taxonomy", format = "list", size = 1)
        @test length(split(String(res.body))) == 1
    end

    @testset "uniprotnext" begin
        query = "gene_exact:IGF1R AND reviewed:true"
        res = uniprotsearch(query, format = "list", size = 2)
        total = parse(Int, HTTP.header(res, "X-Total-Results"))
        @test total > 2
        accessions = split(String(res.body))
        @test length(accessions) == 2
        while (res = uniprotnext(res)) !== nothing
            append!(accessions, split(String(res.body)))
        end
        @test length(accessions) == total
        @test allunique(accessions)

        res = uniprotstream(query, format = "list")
        @test sort(split(String(res.body))) == sort(accessions)
    end

    @testset "uniprotstream" begin
        res = uniprotstream("accession:P08069 OR accession:P35626", format = "list")
        @test res.status == 200
        @test sort(split(String(res.body))) == ["P08069", "P35626"]
    end

    @testset "compressed" begin
        res = uniprotentry("P08069", format = "fasta", compressed = true)
        @test res.body[1:2] == [0x1f, 0x8b]   # gzip magic number
    end

    @testset "ID mapping" begin
        res = uniprotidmappingfields()
        body = JSON.parse(String(res.body))
        names = [item["name"] for group in body["groups"] for item in group["items"]]
        @test "UniProtKB_AC-ID" ∈ names
        @test "Ensembl" ∈ names

        ids = ["ENSMUSG00000067064", "ENSMUSG00000057464"]
        res = uniprotidmapping(ids, from = "Ensembl")
        @test res.status == 200
        jobid = JSON.parse(String(res.body))["jobId"]

        status = uniprotidmappingstatus(jobid)
        t0 = time()
        while status.status == 200 && time() - t0 < 120
            @test JSON.parse(String(status.body))["jobStatus"] ∈ ("NEW", "RUNNING")
            sleep(1)
            status = uniprotidmappingstatus(jobid)
        end
        @test status.status == 303

        details = JSON.parse(String(uniprotidmappingdetails(jobid).body))
        @test details["from"] == "Ensembl"
        @test split(details["ids"], ',') == ids

        res = uniprotidmappingresults(jobid)
        pairs = JSON.parse(String(res.body))["results"]
        @test Set(p["from"] for p in pairs) == Set(ids)
        @test any(p -> p["from"] == "ENSMUSG00000067064" && p["to"] == "Q8VGU4", pairs)

        res = uniprotidmappingresults(jobid, stream = true)
        @test JSON.parse(String(res.body))["results"] == pairs

        res = uniprotidmappingresults(jobid, dataset = "uniprotkb", fields = "accession", format = "tsv")
        lines = split(chomp(String(res.body)), '\n')
        @test lines[1] == "From\tEntry"
        @test "ENSMUSG00000067064\tQ8VGU4" ∈ lines

        res = uniprotidmappingresults(jobid, dataset = "uniprotkb", stream = true, format = "list")
        @test Set(split(String(res.body))) == Set(p["to"] for p in pairs)

        @test_throws "`dataset` must be `nothing` or one of" uniprotidmappingresults(jobid, dataset = "taxonomy")
    end

end
