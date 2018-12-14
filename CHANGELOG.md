# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
- Interfaces to EUtils (Enztrez Utilities) and UMLS (Unified Medical Language System)
  APIs.


[Unreleased]: https://github.com/BioJulia/BioServices.jl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/BioJulia/BioServices.jl/tree/v0.2.0
[0.1.3]: https://github.com/BioJulia/BioServices.jl/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/BioJulia/BioServices.jl/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/BioJulia/BioServices.jl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/BioJulia/BioServices.jl/tree/v0.1.0
