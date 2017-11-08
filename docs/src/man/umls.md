```@meta
CurrentModule = BioServices.UMLS
```

# UMLS

Search the Unified Medical Language System (UMLS), for more details visit the [REST API](https://documentation.uts.nlm.nih.gov/rest/home.html).

Searching the UMLS requires approved credentials.
You can sign up [here](https://uts.nlm.nih.gov//license.html)

## Import module
```
using BioServices.UMLS
```

## Exported Functions

| Function                                | Description                   | 
| :-------                                | :----------                   |
| [`get_tgt`](#get-ticket-granting-ticket)| Get a ticket-granting ticket  |
| [`search_umls`](#search-umls)           | Search UMLS Rest API          |
| [`best_match_cui`](#best-cui)           | Return concept ID of best match for a serach|
| [`get-cui`](#search-based-on-cui)       | Get information associated with a Concept ID(CUI)|
| [`get_semantic_types`](#semantic-types) | Retrieve smenatic types associated with a CUI|

--------------------------------------------------
## Method's documentation
--------------------------------------------------

### Get ticket-granting ticket 
```@docs
 get_tgt(; force_new::Bool = false, kwargs...)
```
--------------------------------------------------

### Search UMLS

```@docs
search_umls(tgt, query; version::String="current", timeout=1)
```
--------------------------------------------------

### Best CUI

```@docs
 best_match_cui(result_pages)
```
--------------------------------------------------

### Search based on CUI
```@docs
 get_cui(tgt,cui)
```
--------------------------------------------------

### Semantic types

```@docs
get_semantic_types(tgt, cui; version="current")
```
--------------------------------------------------
