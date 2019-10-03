```@meta
CurrentModule=BioServices.GGGenome
```

# GGGenome

GGGenome is a ultrafast DNA sequence search service hosted by Database Center for Life Science (DBCLS). See [GGGenome Help](https://gggenome.dbcls.jp/en/help.html) for more details.

`BioServices.GGGenome` is a Julia module interfaces with the [GGGenome REST API](https://gggenome.dbcls.jp) to query a DNA sequence to various databases programmatically.

## Getting Started

Import module:

```julia
using BioServices.GGGenome
```

## Available Databases

Genome sequences (`hg19`, `mm10`, `dm3`, `ce10`, `TAIR10`, `pombe`, etc.) and other sequence databases (e.g., `refseq`) are available.

Full list of available databases can be found at [https://gggenome.dbcls.jp/en/mm10/help.html#db_list].

## Examples
### Example 1

- Search TTCATTGACAACATT in
- human genome hg19 (default),
- with perfect matches (default),
- in json format.

```
julia> res = gggsearch("TTCATTGACAACATT", format="bed", output="toString");

julia> print(res)
track name=GGGenome description="GGGenome matches"
chr1    83462475        83462490        .       0       +
chr2    161223114       161223129       .       0       +
chr3    15289789        15289804        .       0       +
chr3    84619844        84619859        .       0       +
....
```

### Example 2

- Search TTCATTGACAACATTGCGT in
- mouse genome mm10,
- allowing 2 mismatches/gaps,
- search for + strand only,
- in tab-delimited txt format.


```
julia> res = gggsearch("TTCATTGACAACATTGCGT", db="mm10", k=2, strand="+", format="txt", output="toString");

julia> print(res)
# [ GGGenome | 2018-07-01 22:59:01 ]
# database:     Mouse genome, GRCm38/mm10 (Dec, 2011)
# query:        TTCATTGACAACATTGCGT
# count:        41
# name  strand  start   end     snippet snippet_pos     snippet_end
chr1    +       19461997        19462014        AGTTATTCAGCTTTCTATCACGATCAGAGAACAAGCTGAGAAAAGGATGTTTTTGCTTTTGCTTTTGTTTTTCTTCTTATTTTGGAGTTCTCATCCATGATTCATTGACACCATTGCTTTGGCCTCTGGGAAGGGCAGCATATCTGGGTAAAAGCAGATAGCAGAGCAAATCTGCTTACTGCAACCAGCCAGGAAGGAAGCAATGAAAGCACGTTCAC  19461897        19462114
chr1    +       98281503        98281520        TCTAGTGAGGAGAAATGTAAGCTAACGTGATAAACATTGTTTCTGATACACTAATTAAACTGACTTTTGAAAAGATGGCTTACATGTCTATCTAACATGTTTCATTGACACCATTGCTATAGTATGTAATTTTAATGTAAAATAGCCTTCTTTGCAGGGAATCCAGCCTGCTGCTGAATCTTTAAATTTTCAGTGTCTGTTGTCATAGTAACCAGAAT  98281403        98281620
...
```

## Understanding `output` parameters

By default, `gggsearch()` returns a `HTTP.Messages.Response` object.

```
julia> query = "GTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGA";

julia> res = gggsearch(query, db="refseq", format="txt");

julia> typeof(res)
HTTP.Messages.Response
```

By setting `output="toString"`, `gggsearch()` returns a `String` object.

```
julia> query = "GTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGA";

julia> res = gggsearch(query, db="refseq", format="txt", output="toString");

julia> typeof(res)
String

julia> println(res)
# [ GGGenome | 2018-07-01 22:25:16 ]
# database:     RefSeq complete RNA release 88 (May, 2018)
# query:        GTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGA
# count:        15
# query:        TCCCGCCGGCTTCTCCGGGATCGGTCGCGTTACCGCAC
# count:        10
# name  strand  start   end     snippet snippet_pos     snippet_end
NR_003279.1 Mus musculus 28S ribosomal RNA (Rn28s1), ribosomal RNA      +       2326    2363    GAAGGGACGGGCGATGGCCTCCGTTGCCCTCGGCCGATCGAAAGGGAGTCGGGTTCAGATCCCCGAATCCGGAGTGGCGGAGATGGGCGCCGCGAGGCCAGTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGAGGCCTCGGGGAGAGTTCTCTTTTCTTTGTGAAGGGCAGGGCGCCCTGGAATGGGTTCGCCCCGAGAGAGGGGCCCGTGCCTTGGAAAGCGTCGCGGTTCC      2226    2463
NR_003287.4 Homo sapiens RNA, 28S ribosomal N5 (RNA28SN5), ribosomal RNA        +       2574    2611    GGGACGGGCGATGGCCTCCGTTGCCCTCGGCCGATCGAAAGGGAGTCGGGTTCAGATCCCCGAATCCGGAGTGGCGGAGATGGGCGCCGCGAGGCGTCCAGTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGAGCCCCGGGGAGAGTTCTCTTTTCTTTGTGAAGGGCAGGGCGCCCTGGAATGGGTTCGCCCCGAGAGAGGGGCCCGTGCCTTGGAAAGCGTCGCGGTTCCG      2474    2711
...
```

By setting `output="extractTopHit"`, `gggsearch()` returns a `String` object containing the top hit. Currently, this only works with `format="txt"`.

```
julia> query = "GTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGA";

julia> res = gggsearch(query, db="refseq", format="txt", output="extractTopHit");

julia> typeof(res)
String

julia> println(res)
NR_003279.1 Mus musculus 28S ribosomal RNA (Rn28s1), ribosomal RNA      +       2326    2363    GAAGGGACGGGCGATGGCCTCCGTTGCCCTCGGCCGATCGAAAGGGAGTCGGGTTCAGATCCCCGAATCCGGAGTGGCGGAGATGGGCGCCGCGAGGCCAGTGCGGTAACGCGACCGATCCCGGAGAAGCCGGCGGGAGGCCTCGGGGAGAGTTCTCTTTTCTTTGTGAAGGGCAGGGCGCCCTGGAATGGGTTCGCCCCGAGAGAGGGGCCCGTGCCTTGGAAAGCGTCGCGGTTCC      2226    2463
```

## Methods

```@docs
    gggsearch(query::AbstractString; 
        db="hg19", k=0, strand=nothing,
        format="html", timeout=5,
        output=nothing, show_url=false)
Retrieve results of gggenome search for a nucleotide sequence.

# Arguments
## Required
- `query::String`: Nucleotide sequence, case insensitive.

## Optional
- `db::String`: Target database name. hg19 if not specified. Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list
- `k::Integer`: Maximum number of mismatches/gaps. 0 if not specified.
- `strand::String`: '+' ('plus') or '-' ('minus') to search specified strand only.
- `format::String`: [html|txt|csv|bed|gff|json]. html if not specified.
- `timeout::Integer`
- `output::String`: If "toString", a String object is returned. If "extractTopHit", a String object containing only top hit is returned (Currently, only works with format="txt"). Otherwise, A HTTP.Messages.Response object is returned.
- `show_url::Bool`: If true, print URL of REST API.
```
--------------------------------------------------

```@docs
    gggdbs()
Retrieve full list of available databases.

Full list of databases: [https://gggenome.dbcls.jp/en/help.html#db_list].
```
--------------------------------------------------
