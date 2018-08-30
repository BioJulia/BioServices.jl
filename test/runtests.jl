module TestBioServices

using BioServices.EUtils
using BioServices.UMLS
using BioServices.GGGenome
using XMLDict
using Test

all_tests = [
    ("eutils.jl",   "       Testing: EUtils"),
    ("umls.jl",     "       Testing: UMLS"),
    ("gggenome.jl",     "   Testing: GGGenome")
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
