@testset "UniProt" begin

    @testset "identifiers" begin
        # Examples from https://www.uniprot.org/help/accession_numbers
        for acc in ("A2BC19", "P12345", "A0A023GPI8", "Q8VGW6", "O14746")
            @test isuniprotaccession(acc)
            @test @inferred(uniprotaccession(acc)) == acc
        end
        for s in ("Q8VGW67", "q8vgw6", "QV8GW6", "P0806", "A0A023GPI", "P05067-2", "P05067.3", "IGF1R")
            @test !isuniprotaccession(s)
        end

        @test uniprotaccession("Q8VGW6_MOUSE") == "Q8VGW6"
        @test uniprotaccession("A0A023GPI8_HUMAN") == "A0A023GPI8"
        @test uniprotaccession("Q8VGW6.37") == "Q8VGW6"
        @test uniprotaccession("P05067-2") == "P05067"
        @test uniprotaccession("Q8VGW6_MOUSE/31-308") == "Q8VGW6"
        @test uniprotaccession("Q5QD11|reviewed|Trace") == "Q5QD11"
        @test uniprotaccession("P08069 extra text") == "P08069"
        @test uniprotaccession("tr|M3WEA8|M3WEA8_FELCA Olfactory receptor family 51 subfamily S member 1 OS=Felis catus OX=9685 GN=OR51S1 PE=4 SV=2") == "M3WEA8"
        @test uniprotaccession(">sp|P05067-2|A4_HUMAN Isoform APP305 of Amyloid-beta precursor protein OS=Homo sapiens OX=9606 GN=APP") == "P05067"
        @test_throws "no UniProt accession found at the start of \"Q8VGW67_MOUSE/31-308\"" uniprotaccession("Q8VGW67_MOUSE/31-308")
        @test_throws "no UniProt accession found" uniprotaccession("q8vgw6_MOUSE")
        @test_throws "no UniProt accession found" uniprotaccession("QV8GW6_MOUSE")
        @test_throws "no UniProt accession found" uniprotaccession("P080690")
        @test_throws "use `uniprotsearch(\"id:IGF1R_HUMAN\")`" uniprotaccession("IGF1R_HUMAN")

        @test @inferred(uniprotentryname("IGF1R_HUMAN")) == (protein = "IGF1R", species = "HUMAN")
        @test uniprotentryname("Q8VGW6_MOUSE") == (protein = "Q8VGW6", species = "MOUSE")
        @test uniprotentryname("A0A023GPI8_HUMAN") == (protein = "A0A023GPI8", species = "HUMAN")
        @test uniprotentryname("POL_HV1B1") == (protein = "POL", species = "HV1B1")
        @test_throws "\"Q8VGW6_MOUSE/31-308\" is not a UniProt entry name (X_Y)" uniprotentryname("Q8VGW6_MOUSE/31-308")
        @test_throws "is not a UniProt entry name" uniprotentryname("IGF1RX_HUMAN")
        @test_throws "is not a UniProt entry name" uniprotentryname("P08069")

        h = uniprotfastaheader(">sp|P08069|IGF1R_HUMAN Insulin-like growth factor 1 receptor OS=Homo sapiens OX=9606 GN=IGF1R PE=1 SV=1")
        @test h == (
            db = "sp", id = "P08069", entryname = "IGF1R_HUMAN",
            proteinname = "Insulin-like growth factor 1 receptor", organism = "Homo sapiens",
            taxid = 9606, gene = "IGF1R", existence = 1, version = 1,
        )
        h = uniprotfastaheader("tr|M3WEA8|M3WEA8_FELCA Olfactory receptor family 51 subfamily S member 1 OS=Felis catus OX=9685 GN=OR51S1 PE=4 SV=2")
        @test h.db == "tr"
        @test h.organism == "Felis catus"
        @test h.gene == "OR51S1"
        @test h.existence == 4
        @test h.version == 2
        # isoforms have no PE or SV
        h = uniprotfastaheader(">sp|P05067-2|A4_HUMAN Isoform APP305 of Amyloid-beta precursor protein OS=Homo sapiens OX=9606 GN=APP")
        @test h.id == "P05067-2"
        @test h.proteinname == "Isoform APP305 of Amyloid-beta precursor protein"
        @test h.gene == "APP"
        @test h.existence === h.version === nothing
        # entries without a gene name have no GN
        h = uniprotfastaheader(">tr|A0A023GPI8|A0A023GPI8_CANAL Lectin OS=Canavalia lineata OX=28957 PE=1 SV=1")
        @test h.gene === nothing
        @test h.existence == 1
        @test_throws "is not a UniProtKB FASTA header" uniprotfastaheader(">UniRef90_P08069 Insulin-like growth factor 1 receptor n=1 Tax=Homo sapiens TaxID=9606 RepID=IGF1R_HUMAN")
        @test_throws "is not a UniProtKB FASTA header" uniprotfastaheader("P08069")
    end

    @testset "uniprotentry" begin
        res = uniprotentry("P08069", format = "fasta")
        @test res.status == 200
        @test startswith(Dict(res.headers)["Content-Type"], "text/plain")
        fasta = String(res.body)
        @test startswith(fasta, ">sp|P08069|IGF1R_HUMAN")
        h = uniprotfastaheader(first(eachline(IOBuffer(fasta))))
        @test h.id == "P08069"
        @test h.taxid == 9606
        @test uniprotentryname(h.entryname).species == "HUMAN"

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
