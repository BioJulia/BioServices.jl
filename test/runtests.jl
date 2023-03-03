module TestBioServices

using BioServices.EUtils
using BioServices.UMLS
using BioServices.GGGenome
using BioServices.bioDBnet
using BioServices.EBIProteins
using XMLDict
using JSON
using Test

all_tests = [
    ("eutils.jl",   "       Testing: EUtils"),
    ("umls.jl",     "       Testing: UMLS"),
    ("gggenome.jl",     "   Testing: GGGenome"),
    ("bioDBnet.jl",     "   Testing: bioDBnet"),
    ("ebiproteins.jl", "      Testing: EBIProteins")
    ]

println("Running tests:")

for (t, test_string) in all_tests
    println("-----------------------------------------")
    println("-----------------------------------------")
    println(test_string)
    println("-----------------------------------------")
    println("-----------------------------------------")
    include(t)
end

end # TestBioServices
