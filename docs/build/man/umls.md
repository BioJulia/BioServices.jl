


<a id='UMLS-1'></a>

# UMLS


Search the Unified Medical Language System (UMLS), for more details visit the [REST API](https://documentation.uts.nlm.nih.gov/rest/home.html).


Searching the UMLS requires approved credentials. You can sign up [here](https://uts.nlm.nih.gov//license.html)


<a id='Import-module-1'></a>

## Import module


```
using BioServices.UMLS
```


<a id='Exported-Functions-1'></a>

## Exported Functions


| Function                                 | Description                                       |
|:---------------------------------------- |:------------------------------------------------- |
| [`get_tgt`](#get-ticket-granting-ticket) | Get a ticket-granting ticket                      |
| [`search_umls`](#search-umls)            | Search UMLS Rest API                              |
| [`best_match_cui`](#best-cui)            | Return concept ID of best match for a serach      |
| [`get-cui`](#search-based-on-cui)        | Get information associated with a Concept ID(CUI) |
| [`get_semantic_types`](#semantic-types)  | Retrieve smenatic types associated with a CUI     |


---


<a id='Method's-documentation-1'></a>

## Method's documentation


---


<a id='Get-ticket-granting-ticket-1'></a>

### Get ticket-granting ticket

<a id='BioServices.UMLS.get_tgt-Tuple{}' href='#BioServices.UMLS.get_tgt-Tuple{}'>#</a>
**`BioServices.UMLS.get_tgt`** &mdash; *Method*.



get_tgt(; force_new::Bool = false, kwargs...)

Retrieve a ticket granting ticket (TGT) using 

1. UTS username and password OR
2. apikey

A tgt is valid for 8 hours. Therefore, look for UTS_TGT.txt in the local directory to see if it has been recently stored. One can force getting a  new ticket by passing keyword argument `force_new=true` 

###Examples

```julia
tgt = get_tgt(username = "myuser", password = "mypass")
```

```julia
tgt = get_tgt(apikey = "mykey")
```


---


<a id='Search-UMLS-1'></a>

### Search UMLS

<a id='BioServices.UMLS.search_umls-Tuple{Any,Any}' href='#BioServices.UMLS.search_umls-Tuple{Any,Any}'>#</a>
**`BioServices.UMLS.search_umls`** &mdash; *Method*.



search_umls(tgt, query)

Search UMLS Rest API. For more info see [UMLS_API](https://documentation.uts.nlm.nih.gov/rest/search/)

###Arguments

  * `tgt`: Ticket Granting Ticket
  * `query`: UMLS query containing the search term
  * `version:` Optional - defaults to current

###Output

  * `result_pages`: Array, where each entry is a dictionary containing a page of

results. e.g

```julia
Dict{AbstractString,Any} with 3 entries:
"pageSize"   => 25
"pageNumber" => 1
"result"     => Dict{AbstractString,Any}("classType"=>"searchResults","result…
```

###Examples

```julia
credentials = Credentials(user, psswd)
tgt = get_tgt(credentials)
term = "obesity"
query = Dict("string"=>term, "searchType"=>"exact" )
all_results= search_umls(tgt, query)
```


---


<a id='Best-CUI-1'></a>

### Best CUI

<a id='BioServices.UMLS.best_match_cui-Tuple{Any}' href='#BioServices.UMLS.best_match_cui-Tuple{Any}'>#</a>
**`BioServices.UMLS.best_match_cui`** &mdash; *Method*.



best_match_cui(result_pages)

Retrive the best match from array of all result pages

###Example

```julia
cui = best_match_cui(all_results)
```


---


<a id='Search-based-on-CUI-1'></a>

### Search based on CUI

<a id='BioServices.UMLS.get_cui-Tuple{Any,Any}' href='#BioServices.UMLS.get_cui-Tuple{Any,Any}'>#</a>
**`BioServices.UMLS.get_cui`** &mdash; *Method*.



get_cui(tgt,cui)

Retrieve information (name, semantic types, number of atoms, etc) for a known CUI  from latest UMLS version or a specific release.

Returns UTS json response

See: https://documentation.uts.nlm.nih.gov/rest/concept

**Example**

```julia
tgt = get_tgt(apikey = "mykey")
cui = "C0028754"
concept = get_cui(tgt, cui)
```


---


<a id='Semantic-types-1'></a>

### Semantic types

<a id='BioServices.UMLS.get_semantic_types-Tuple{Any,Any}' href='#BioServices.UMLS.get_semantic_types-Tuple{Any,Any}'>#</a>
**`BioServices.UMLS.get_semantic_types`** &mdash; *Method*.



get_semantic_types(c::Credentials, cui)

Return an array of the semantic types associated with a cui

**Example**

```julia
tgt = get_tgt(apikey = "mykey")
cui = "C0028754"
sm = get_semantic_types(tgt, cui)
```


---

