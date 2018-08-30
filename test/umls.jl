

@testset "UMLS" begin
    user = ""
    psswd = ""
    apikey = ""

    try
        user = ENV["UMLS_USER"]
        psswd = ENV["UMLS_PSSWD"]
        apikey = ENV["UMLS_APIKEY"]
    catch
        @warn "UMLS tests could not run: Set up credentials as enviroment variables: UMLS_USER, UMLS_PSSWD and UMLS_APIKEY"
    end

    if (user != "") && (psswd != "") && (apikey != "")
        term = "obesity"
        query = Dict("string"=>term, "searchType"=>"exact" )

        tgt = get_tgt(force_new=true, username=user, password=psswd)
        #do it again to test reading from file
        tgt = get_tgt(username=user, password=psswd)
        #test apikey
        tgt = get_tgt(force_new=true, apikey=apikey)

        @testset "Testing Search/Content/CUI" begin
            all_results= search_umls(tgt, query)
            @test length(all_results[1]["result"]["results"]) == 2
            cui = best_match_cui(all_results)
            @test cui == "C0028754"
            sm = get_semantic_types(tgt, cui)
            @test sm[1] == "Disease or Syndrome"
        end
    end
end
