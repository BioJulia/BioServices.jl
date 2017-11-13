using Documenter, BioServices

makedocs()
deploydocs(
    deps = Deps.pip("mkdocs", "pygments", "mkdocs-material"),
    repo = "github.com/BioJulia/BioServices.jl.git",
    julia = "0.6",
    osname = "linux",
)
