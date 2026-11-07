module TestBioServices

using BioServices.Sessions
using BioServices.EUtils
using BioServices.UMLS
using BioServices.GGGenome
using BioServices.EBIProteins
using BioServices.UniProt
using HTTP
using JSON
using XMLDict
using Test
import Downloads, HTTP

println("Running tests:")
include("common.jl")
include("sessions.jl")

all_tests = [
    ("eutils.jl", "      Testing: EUtils"),
    ("umls.jl", "      Testing: UMLS"),
    ("gggenome.jl", "      Testing: GGGenome"),
    ("ebiproteins.jl", "      Testing: EBIProteins"),
    ("uniprot.jl", "      Testing: UniProt"),
]

# The live suites run once with each client; `s` holds the sessions, one per service, that they run their requests with.
foreach((HTTPClient(), DownloadsClient())) do client
    global s = [Session(client, svc) for svc in (EBIProteinsAPI(), UniProtAPI(), GGGenomeAPI(), UMLSAPI(), EUtilsAPI())]
    @testset "$(nameof(typeof(client)))" begin
        foreach(all_tests) do (t, test_string)
            println("-----------------------------------------")
            println(test_string, " with ", nameof(typeof(client)))
            println("-----------------------------------------")
            include(t)
        end
    end
end

end # TestBioServices
