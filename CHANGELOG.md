# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [UNRELEASED]
### Added
- UniProt module for the UniProt REST API (rest.uniprot.org): entry retrieval, search, and ID mapping, together with parsers for UniProt accessions, entry names, and FASTA headers.
- Documentation for the EBIProteins module.
### Changes
- The Julia code is formatted with Runic, and CI checks the formatting of every pull request.
- Text files are stored with LF line endings.
- Julia 1.10 or later is required.
- The service functions return requests instead of sending them, and a session from `BioServices.Sessions` runs them: `run(Session(DownloadsClient(), EUtilsAPI()), einfo(db = "pubmed"))`.
  A session is for one service, with its own rate limiter, and sessions combine as a vector that runs each request with the session for its service.
  Work that needs several requests, such as `search_umls` and `get_tgt`, is a `Workflow`, which sessions run too.
  Any other type, such as an endpoint type of a generated client, can be run once it has a `Request(x)` method.
- HTTP.jl is no longer a dependency.
  Sessions send requests with HTTP.jl 2.4 or later (`HTTPClient()`) or Downloads.jl (`DownloadsClient()`), each loaded by a package extension when you load that package.
- Each service has tuned policies: timeouts, retries honouring `Retry-After`, redirects, a rate limit per service (UMLS 20 per second; E-utilities 3 per second, or 10 with an API key), and keys kept out of errors.
  `configure` changes a session's credentials, policies or client, or those of every session for a service in a vector.
- `search_pages` returns the pages of a UMLS search as a lazy iterator.
- Results are a `Sessions.Response` with `status`, `headers` (a vector of pairs) and `body` (bytes), which can be read more than once; use `header(res, name)` to look up a header.
  Failures throw `StatusError`, `TransportError` or `RedirectError`.
- The `timeout` keyword of `gggsearch` and `search_umls` and the `show_url` keyword of `gggsearch` are removed: timeouts are session policies, and `Sessions.url` gives a request's URL.
- `esearch` and `epost` no longer update their context; `context(ctx, res)` returns the context with the History server's `WebEnv` and `query_key`, and `set_context!` updates it in place.
- `gggsearch` leaves `k = 0` out of the URL, because GGGenome redirects such URLs to plain http, which sessions refuse.
- URLs and form bodies are built and percent-encoded with URIs.jl, in one place, and redirects are resolved as RFC 3986 says.
- Fixed: GGGenome's `db`, `strand` and `query`, UMLS's `version` and `cui`, and the EBI Proteins `ebivariation` accession are percent-encoded in URL paths.
- Fixed: EBI Proteins query values for `upid`, `accession`, `id`, `dbid` and `upi` are no longer percent-encoded twice.

# [0.4.0] - 2021-04-17
### Changes
- eutils.jl now retries requests that have been rate-limited ([#26](https://github.com/BioJulia/BioServices.jl/pull/26)).
- Added EBIProteins ([#27](https://github.com/BioJulia/BioServices.jl/pull/37)).
- Updated CI / documentation building ([#36](https://github.com/BioJulia/BioServices.jl/pull/39) and lots of others)
  - also removes julia < 1.0 support

## [0.3.2] - 2018-12-13
### Changes
- eutils.jl set `retry_non_idempotent=true` on http requests
### Added
- Project.toml

## [0.3.1] - 2018-10-5
### Changes
- eutils.jl to use the correct http parameter when passing the body to POST
- tests/eutils.jl to perform efetch with large number of PMID which breaks if incorrect http format is used
### Removed
- *.toml files to wait until versioning is ready for new Pkg

## [0.3.0] - 2018-09-21
### Changed
- Updated HUMANS.md.
- Added compatibility with Julia 1.0

## [0.2.0] - 2018-07-18
### Changed
- Updated project files.
### Added
- Add GGGenome ([#12](https://github.com/BioJulia/BioServices.jl/pull/12)).

## [0.1.3] - 2018-06-28
### Changed
- Use XMLDict instead of EzXML until EzXML installation is fixed.

## [0.1.2] - 2018-05-22
### Changed
- Optionally retry after HTTP posts to UMLS fail.

## [0.1.1] - 2018-05-16
### Added
- Contributing, code of conduct, and github templates rollout.

### Changed
- EUtils now uses HTTP.jl.
- Test coverage increases.

### Removed
- :exclamation: Dropped deprecated libraries from UMLS.jl.

## [0.1.0] - 2017-11-14
### Added
- The first release of BioServices as in independent module in BioJulia.
  (Transferred from Bio.jl).
- Interfaces to EUtils (Enztrez Utilities) and UMLS (Unified Medical Language System) APIs.

[UNRELEASED]: https://github.com/BioJulia/BioServices.jl/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/BioJulia/BioServices.jl/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/BioJulia/BioServices.jl/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/BioJulia/BioServices.jl/tree/v0.3.0
[0.2.0]: https://github.com/BioJulia/BioServices.jl/tree/v0.2.0
[0.1.3]: https://github.com/BioJulia/BioServices.jl/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/BioJulia/BioServices.jl/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/BioJulia/BioServices.jl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/BioJulia/BioServices.jl/tree/v0.1.0
