module TestBioServices

using BioServices.EUtils
using BioServices.UMLS
using XMLDict
using Base.Test

all_tests = [
    ("eutils.jl",   "       Testing: EUtils"),
    ("umls.jl",     "       Testing: UMLS")
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
