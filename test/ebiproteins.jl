@testset "EBIProteins" begin

    # A repeated XML element parses to a Vector, a single one to the element itself
    aslist(x) = x isa AbstractVector ? x : [x]

    # Searches return whichever entries the current release ranks first, so their results are checked by form, not by value.
    isaccession(x) = occursin(r"^([OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2})$", x)
    isupi(x) = occursin(r"^UPI[0-9A-F]{10}$", x)

    @testset "ebiproteins" begin
        @testset "ebiproteins" begin
            res = run(
                s, ebiproteins(
                    reviewed = true, keywords = "kinase", size = 1, seqLength = 813,
                    organism = "Oryza sativa subsp. indica", contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entry")
            @test isa(body["entry"], XMLDict.XMLDictElement)
            @test haskey(body["entry"], "accession")
            @test isaccession(first(aslist(body["entry"]["accession"])))
        end

        @testset "ebiproteins accession" begin
            accession = "P08069"
            res = run(s, ebiproteins(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entry")
            @test body["entry"]["accession"][1] == accession
        end

        @testset "ebiproteins interaction" begin
            accession = "P08069"
            res = run(s, ebiproteins(accession = accession, operation = "interaction", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "upInteraction")
        end

        @testset "ebiproteins isoforms" begin
            accession = "Q9NXB0"
            res = run(s, ebiproteins(accession = accession, subset = "isoforms", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entry")
            @test isa(body["entry"][1], XMLDict.XMLDictElement)
            @test haskey(body["entry"][1], "accession")
            @test body["entry"][1]["accession"] == accession * "-1"
        end

        @testset "ebiproteins dbtype/dbid" begin
            dbtype = "Ensembl"
            dbid = "ENSP00000351276"
            res = run(s, ebiproteins(dbtype = dbtype, dbid = dbid, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entry")
            @test isa(body["entry"], XMLDict.XMLDictElement)
            @test haskey(body["entry"], "accession")
            @test body["entry"]["accession"][1] == "P21802"
        end
    end

    @testset "ebifeatures" begin
        @testset "ebifeatures" begin
            types = "domain"
            res = run(
                s, ebifeatures(
                    reviewed = true, types = types, keywords = "kinase", size = 1, seqLength = 813,
                    organism = "Oryza sativa subsp. indica", contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            @test isa(body["entryFeature"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"], "accession")
            @test isaccession(body["entryFeature"]["accession"])
            @test haskey(body["entryFeature"], "feature")
            @test isa(body["entryFeature"]["feature"][1], XMLDict.XMLDictElement)
            @test body["entryFeature"]["feature"][1][:type] == types
        end

        @testset "ebifeatures accession" begin
            accession = "P08069"
            res = run(s, ebifeatures(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == accession
            @test haskey(body, "feature")
            @test isa(body["feature"][1], XMLDict.XMLDictElement)
        end

        @testset "ebifeatures type" begin
            type = "domain"
            res = run(s, ebifeatures(type = type, size = 1, terms = "Kinase", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            @test isa(body["entryFeature"], XMLDict.XMLDictElement)
            features = aslist(body["entryFeature"]["feature"])
            @test all(f -> isa(f, XMLDict.XMLDictElement), features)
            @test any(f -> f[:type] == type, features)
        end
    end

    @testset "ebivariation" begin
        @testset "ebivariation" begin
            res = run(s, ebivariation(omim = 104300, size = 1, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            @test isa(body["entryFeature"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"], "accession")
            @test !isempty(body["entryFeature"]["accession"])
            @test haskey(body["entryFeature"], "feature")
            features = aslist(body["entryFeature"]["feature"])
            @test all(f -> isa(f, XMLDict.XMLDictElement), features)
            @test all(f -> f[:type] == "Variant", features)
        end

        @testset "ebivariation accession" begin
            accession = "P08069"
            res = run(s, ebivariation(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == accession
            @test haskey(body, "feature")
            @test body["feature"][1][:type] == "Variant"
        end

        @testset "ebivariation hgvs" begin
            res = run(s, ebivariation(hgvs = "NC_000017.11:g.58219213C>T", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            entries = aslist(body["entryFeature"])
            @test isa(entries[1], XMLDict.XMLDictElement)
            @test haskey(entries[1], "accession")
            # the set and order of entries mapping to a genomic position can change
            @test "Q9NXB0" in [e["accession"] for e in entries]
            @test haskey(entries[1], "feature")
            @test aslist(entries[1]["feature"])[1][:type] == "Variant"
        end

        @testset "ebivariation dbid" begin
            res = run(s, ebivariation(dbid = "rs121918508", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            entries = aslist(body["entryFeature"])
            @test isa(entries[1], XMLDict.XMLDictElement)
            @test haskey(entries[1], "accession")
            @test "P21802" in [e["accession"] for e in entries]
            @test haskey(entries[1], "feature")
            @test aslist(entries[1]["feature"])[1][:type] == "Variant"
        end
    end

    @testset "ebiproteomics" begin
        @testset "ebiproteomics" begin
            accession = "P08069"
            peptide = "ACTENNECCHPECLGSCSAPDNDTACVACR"
            res = run(
                s, ebiproteomics(
                    accession = accession, peptide = peptide,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            @test isa(body["entryFeature"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"], "accession")
            @test body["entryFeature"]["accession"] == accession
            @test haskey(body["entryFeature"], "feature")
            @test isa(body["entryFeature"]["feature"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"]["feature"], "peptide")
            @test isa(body["entryFeature"]["feature"]["peptide"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"]["feature"]["peptide"], "peptideSequence")
            @test body["entryFeature"]["feature"]["peptide"]["peptideSequence"] == peptide
        end

        @testset "ebiproteomics accession" begin
            accession = "P08069"
            res = run(s, ebiproteomics(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == accession
            @test haskey(body, "feature")
            @test haskey(body["feature"][1], "peptide")
        end
    end

    @testset "ebiantigen" begin
        @testset "ebiantigen" begin
            accession = "P08069"
            antigen_sequence = "YIVRWQRQPQDGYLYRHNYCSKDKIPIRKYADGTIDIEEVTENPKTEVCGGEKGPCCACPKTEAEKQAEKEEA"
            res = run(
                s, ebiantigen(
                    accession = accession, antigen_sequence = antigen_sequence,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entryFeature")
            @test isa(body["entryFeature"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"], "accession")
            @test body["entryFeature"]["accession"] == accession
            @test haskey(body["entryFeature"], "feature")
            @test isa(body["entryFeature"]["feature"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"]["feature"], "antigen")
            @test isa(body["entryFeature"]["feature"]["antigen"], XMLDict.XMLDictElement)
            @test haskey(body["entryFeature"]["feature"]["antigen"], "antigenSequence")
            @test body["entryFeature"]["feature"]["antigen"]["antigenSequence"] == antigen_sequence
        end

        @testset "ebiantigen accession" begin
            accession = "P08069"
            res = run(s, ebiantigen(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == accession
            @test haskey(body, "feature")
            @test any(f -> haskey(f, "antigen"), aslist(body["feature"]))
        end
    end

    @testset "ebiproteomes" begin
        @testset "ebiproteomes" begin
            name = "Caenorhabditis elegans (Bristol N2)"
            res = run(
                s, ebiproteomes(
                    size = 1, name = name,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "proteome")
            @test isa(body["proteome"], XMLDict.XMLDictElement)
            @test haskey(body["proteome"], "name")
            @test body["proteome"]["name"] == name
        end

        @testset "ebiproteomes upid" begin
            upid = "UP000001940"
            res = run(s, ebiproteomes(upid = upid, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, :upid)
            @test body[:upid] == upid
        end

        @testset "ebiproteomes upid proteins" begin
            upid = "UP000001940"
            res = run(
                s, ebiproteomes(
                    upid = upid, operation = "proteins", reviewed = true,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, :upid)
            @test body[:upid] == upid
        end

        @testset "ebiproteomes upid query" begin
            # With other parameters, `upid` is sent in the query.
            upid = "UP000001940"
            res = run(s, ebiproteomes(size = 1, upid = upid, contenttype = "application/xml"))
            @test res.status == 200
            @test parse_xml(String(res.body))["proteome"][:upid] == upid
        end
    end

    @testset "ebigenecentric" begin
        @testset "ebigenecentric" begin
            gene = "DLK1"
            res = run(s, ebigenecentric(size = 1, gene = gene, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "canonicalGene")
            @test isa(body["canonicalGene"], XMLDict.XMLDictElement)
            @test haskey(body["canonicalGene"], "relatedGene")
            @test isa(body["canonicalGene"]["relatedGene"], XMLDict.XMLDictElement)
            @test haskey(body["canonicalGene"]["relatedGene"], :geneName)
            @test lowercase(body["canonicalGene"]["relatedGene"][:geneName]) == lowercase(gene)
        end

        @testset "ebigenecentric accession" begin
            accession = "P08069"
            res = run(s, ebigenecentric(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "gene")
            @test isa(body["gene"], XMLDict.XMLDictElement)
            @test haskey(body["gene"], :accession)
            @test body["gene"][:accession] == accession
        end

        @testset "ebigenecentric accession query" begin
            # With other parameters, `accession` is sent in the query.
            accession = "P08069"
            res = run(s, ebigenecentric(size = 1, accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test parse_xml(String(res.body))["canonicalGene"]["gene"][:accession] == accession
        end
    end

    @testset "ebitaxonomy" begin
        @testset "ebitaxonomy ancestor" begin
            res = run(s, ebitaxonomy(operation = "ancestor", ids = "9606,9615", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == "1437010"
        end

        @testset "ebitaxonomy id" begin
            ids = "9606"
            res = run(s, ebitaxonomy(operation = "id", ids = ids, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == ids
        end

        @testset "ebitaxonomy id node" begin
            ids = "9606"
            res = run(s, ebitaxonomy(operation = "id", ids = ids, getnode = true, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == ids
        end

        @testset "ebitaxonomy id parent" begin
            ids = "9606"
            res = run(s, ebitaxonomy(operation = "id", ids = ids, subset = "parent", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == "9605"
        end

        @testset "ebitaxonomy id parent node" begin
            ids = "9606"
            res = run(
                s, ebitaxonomy(
                    operation = "id", ids = ids, subset = "parent", getnode = true,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == "9605"
        end

        @testset "ebitaxonomy id children" begin
            ids = "9606"
            res = run(s, ebitaxonomy(operation = "id", ids = ids, subset = "children", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            @test isa(body["taxonomies"]["taxonomy"][1], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"]["taxonomy"][1], "taxonomyId")
            # the order of children is not stable
            @test "741158" in [t["taxonomyId"] for t in body["taxonomies"]["taxonomy"]]
        end

        @testset "ebitaxonomy id children node" begin
            ids = "9606"
            res = run(
                s, ebitaxonomy(
                    operation = "id", ids = ids, subset = "children", getnode = true,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            @test isa(body["taxonomies"]["taxonomy"][1], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"]["taxonomy"][1], "taxonomyId")
            # the order of children is not stable
            @test "741158" in [t["taxonomyId"] for t in body["taxonomies"]["taxonomy"]]
        end

        @testset "ebitaxonomy id siblings" begin
            ids = "9606"
            res = run(s, ebitaxonomy(operation = "id", ids = ids, subset = "siblings", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            siblings = aslist(body["taxonomies"]["taxonomy"])
            @test all(t -> haskey(t, "taxonomyId"), siblings)
            # the order of siblings is not stable
            @test "1425170" in [t["taxonomyId"] for t in siblings]
            @test !("9606" in [t["taxonomyId"] for t in siblings])
        end

        @testset "ebitaxonomy id siblings node" begin
            ids = "9606"
            res = run(
                s, ebitaxonomy(
                    operation = "id", ids = ids, subset = "siblings", getnode = true,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            siblings = aslist(body["taxonomies"]["taxonomy"])
            @test all(t -> haskey(t, "taxonomyId"), siblings)
            # the order of siblings is not stable
            @test "1425170" in [t["taxonomyId"] for t in siblings]
            @test !("9606" in [t["taxonomyId"] for t in siblings])
        end

        @testset "ebitaxonomy lineage" begin
            ids = "9606"
            res = run(s, ebitaxonomy(operation = "lineage", ids = ids, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            @test isa(body["taxonomies"]["taxonomy"][2], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"]["taxonomy"][2], "taxonomyId")
            @test body["taxonomies"]["taxonomy"][2]["taxonomyId"] == "9605"
        end

        @testset "ebitaxonomy name" begin
            ids = "Homo sapiens"
            res = run(s, ebitaxonomy(operation = "name", ids = ids, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            @test isa(body["taxonomies"]["taxonomy"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"]["taxonomy"], "taxonomyId")
            @test body["taxonomies"]["taxonomy"]["taxonomyId"] == "9606"
        end

        @testset "ebitaxonomy name node" begin
            ids = "Homo sapiens"
            res = run(
                s, ebitaxonomy(
                    operation = "name", ids = ids, getnode = true,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            @test isa(body["taxonomies"]["taxonomy"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"]["taxonomy"], "taxonomyId")
            @test body["taxonomies"]["taxonomy"]["taxonomyId"] == "9606"
        end

        @testset "ebitaxonomy path" begin
            ids = "9606"
            res = run(
                s, ebitaxonomy(
                    operation = "path", ids = ids, depth = 2, direction = "BOTTOM",
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test haskey(body, "children")
        end

        @testset "ebitaxonomy path node" begin
            ids = "9606"
            res = run(
                s, ebitaxonomy(
                    operation = "path", ids = ids, depth = 2, direction = "BOTTOM",
                    getnode = true, contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomies")
            @test isa(body["taxonomies"], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"], "taxonomy")
            @test isa(body["taxonomies"]["taxonomy"][2], XMLDict.XMLDictElement)
            @test haskey(body["taxonomies"]["taxonomy"][2], "taxonomyId")
            # the order of nodes along the path is not stable
            @test "63221" in [t["taxonomyId"] for t in body["taxonomies"]["taxonomy"]]
        end

        @testset "ebitaxonomy relationship" begin
            from = "9606"
            to = "9615"
            res = run(
                s, ebitaxonomy(
                    operation = "relationship", from = "9606", to = "9615",
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == from
            while haskey(body, "parent")
                body = body["parent"]
            end
            while haskey(body, "children")
                body = body["children"]["child"]
            end
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "taxonomyId")
            @test body["taxonomyId"] == to
        end
    end

    @testset "ebicoordinates" begin
        @testset "ebicoordinates" begin
            res = run(s, ebicoordinates(size = 1, taxid = 9606, gene = "DLK1", contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "gnEntry")
            @test isa(body["gnEntry"], XMLDict.XMLDictElement)
            entry = body["gnEntry"]
            @test haskey(entry, "accession")
            # The first entry changes as UniProt adds entries for DLK1, so check what they share.
            @test entry["taxid"] == "9606"
            @test entry["gene"][""] == "DLK1"
            @test haskey(entry, "gnCoordinate")
            coordinate = entry["gnCoordinate"]
            coordinate = coordinate isa AbstractVector ? first(coordinate) : coordinate
            @test coordinate[:ensembl_gene_id] == "ENSG00000185559"
            @test coordinate["genomicLocation"][:chromosome] == "14"
        end

        @testset "ebicoordinates accession" begin
            accession = "P08069"
            res = run(s, ebicoordinates(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == accession
            @test haskey(body, "gnCoordinate")
        end

        @testset "ebicoordinates accession query" begin
            # With other parameters, `accession` is sent in the query.
            accession = "P08069"
            res = run(s, ebicoordinates(size = 1, accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test parse_xml(String(res.body))["gnEntry"]["accession"] == accession
        end

        @testset "ebicoordinates accession pPosition" begin
            accession = "P08069"
            res = run(s, ebicoordinates(accession = accession, pPosition = 1, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "locations")
            @test haskey(body["locations"], "accession")
            @test body["locations"]["accession"] == accession
            @test haskey(body["locations"], "geneStart")
            @test parse(Int, body["locations"]["geneStart"]) > 0
        end

        @testset "ebicoordinates accession pStart pEnd" begin
            accession = "P08069"
            res = run(s, ebicoordinates(accession = accession, pStart = 1, pEnd = 10, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "locations")
            @test haskey(body["locations"], "accession")
            @test body["locations"]["accession"] == accession
            @test haskey(body["locations"], "geneEnd")
            # ten residues span thirty bases, whichever strand and assembly
            @test abs(parse(Int, body["locations"]["geneEnd"]) - parse(Int, body["locations"]["geneStart"])) == 29
        end

        @testset "ebicoordinates dbtype dbid" begin
            dbtype = "Ensembl"
            dbid = "ENSP00000351276"
            res = run(s, ebicoordinates(dbtype = dbtype, dbid = dbid, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "gnEntry")
            @test isa(body["gnEntry"], XMLDict.XMLDictElement)
            @test haskey(body["gnEntry"], "gnCoordinate")
        end

        @testset "ebicoordinates taxonomy" begin
            locations = "98649582-98649611"
            res = run(s, ebicoordinates(taxonomy = 9606, locations = locations, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "gnEntry")
            @test isa(body["gnEntry"][1], XMLDict.XMLDictElement)
            @test haskey(body["gnEntry"][1], "gnCoordinate")
        end

        @testset "ebicoordinates taxonomy feature" begin
            locations = "98649582-98649611"
            res = run(
                s, ebicoordinates(
                    taxonomy = 9606, locations = locations, getfeature = true,
                    contenttype = "application/xml"
                )
            )
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "gnEntry")
            @test isa(body["gnEntry"][1], XMLDict.XMLDictElement)
            @test haskey(body["gnEntry"][1], "gnCoordinate")
        end
    end

    @testset "ebiuniparc" begin
        @testset "ebiuniparc" begin
            sequencechecksum = "9A2813B2801A98BD"
            res = run(s, ebiuniparc(sequencechecksum = sequencechecksum, size = 1, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entry")
            @test isa(body["entry"], XMLDict.XMLDictElement)
            @test haskey(body["entry"], "accession")
            @test body["entry"]["accession"] == "UPI00001AFE16"
        end

        @testset "ebiuniparc accession" begin
            accession = "P08069"
            res = run(s, ebiuniparc(accession = accession, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == "UPI000012D3EA"
        end

        @testset "ebiuniparc bestguess" begin
            res = run(s, ebiuniparc(gene = "DLK1", taxid = 9606, bestguess = true, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test isupi(body["accession"])
        end

        @testset "ebiuniparc dbid" begin
            dbid = "AAC02967"
            res = run(s, ebiuniparc(dbid = dbid, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "entry")
            @test isa(body["entry"], XMLDict.XMLDictElement)
            @test haskey(body["entry"], "accession")
            @test body["entry"]["accession"] == "UPI0000000114"
        end

        @testset "ebiuniparc upid" begin
            upid = "UP000001940"
            res = run(s, ebiuniparc(upid = upid, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            # the service returns an empty <uniparc/> root for this endpoint
            @test_broken haskey(body, "entry")
        end

        @testset "ebiuniparc sequence" begin
            sequence = "MAAFSKYLTARNTSLAGAAFLLLCLLHKRRRALGLHG"
            res = run(s, ebiuniparc(sequence = sequence, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == "UPI0000000114"
        end

        @testset "ebiuniparc upi" begin
            upi = "UPI0000000114"
            res = run(s, ebiuniparc(upi = upi, contenttype = "application/xml"))
            @test res.status == 200
            @test startswith(header(res, "Content-Type"), "application/xml")
            body = parse_xml(String(res.body))
            @test isa(body, XMLDict.XMLDictElement)
            @test haskey(body, "accession")
            @test body["accession"] == "UPI0000000114"
        end
    end
end
