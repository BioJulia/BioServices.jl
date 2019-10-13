using Documenter, DocumenterMarkdown, BioServices

makedocs(
	format	= Markdown(),
	sitename= "BioServices.jl"
)

deploydocs(
    deps 	= Deps.pip("mkdocs", "mkdocs-material", "pygments", "python-markdown-math"),
    repo 	= "github.com/BioJulia/BioServices.jl.git",
    make 	= () -> run(`mkdocs build`),
    target 	= "site"
)
