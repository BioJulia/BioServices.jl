using Documenter, BioServices


makedocs(
    sitename= "BioServices.jl",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "EUtils" => "man/eutils.md",
            "UMLS" => "man/umls.md",
            "GGGenome" => "man/gggenome.md",
            "Home" => "index.md"
            ]
        ],
    authors = "The BioJulia Organisation",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true")
)
            
deploydocs(
    repo 	     = "github.com/BioJulia/BioServices.jl.git",
    push_preview = true,
    devbranch    = "master"
)
