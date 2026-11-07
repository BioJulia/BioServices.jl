# BioServices: APIs for Web Services

The `BioServices` module provides APIs for various web services.

The service modules describe requests, and [sessions](man/sessions.md) run them with the HTTP client you choose, under policies tuned for each service.
A session is for one service, and sessions combine as a vector:

```julia
using BioServices.Sessions, BioServices.EUtils, BioServices.GGGenome, Downloads
s = Session(DownloadsClient(), EUtilsAPI())
res = run(s, einfo(db = "pubmed"))
ss = [s, Session(DownloadsClient(), GGGenomeAPI())]
run(ss, gggsearch("hg38", "TTCATTGACAACATTGCGT"))
```

## Contents

```@contents
Pages = ["man/sessions.md", "man/eutils.md", "man/umls.md", "man/gggenome.md", "man/ebiproteins.md", "man/uniprot.md"]
Depth = 6
```
