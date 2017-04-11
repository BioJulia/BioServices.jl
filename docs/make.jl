using Documenter, BioServices

makedocs()
deploydocs(
    deps = Deps.pip("mkdocs", "pygments", "mkdocs-biojulia"),
    repo = "github.com/BioJulia/BioServices.jl.git",
    julia = "0.5",
    osname = "linux",
)
