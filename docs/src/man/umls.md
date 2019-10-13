```@meta
CurrentModule = BioServices.UMLS
```

# UMLS

The Unified Medical Language System (UMLS) brings together many health and biomedical vocabularies and standards to enable interoperability between biomedical information systems and services. The [UMLS Quick Start Guide](https://www.nlm.nih.gov/research/umls/quickstart.html) provides an overview of the software, tools and services associated with the UMLS.

`BioServices.UMLS` is a Julia module that interfaces with the [UMLS REST API](https://documentation.uts.nlm.nih.gov/rest/home.html) to query the UMLS data programmatically.


## Getting Started

1. [Sign up](https://uts.nlm.nih.gov/license.html) for a UMLS Terminology Services (UTS) account, where you agree to their terms of use.

2. Import the module:

    ```julia
    using BioServices.UMLS
    ```

## Available Endpoints

For a  complete list of the endpoints available through the UMLS REST API visit the [UMLS REST API Documentation](https://documentation.uts.nlm.nih.gov/rest/home.html).

This module focuses on the following three endpoints. (Requests to expand API are encouraged through pull requests or issues in out GitHub repository.)

| EndPoint                                  | Description                   | 
| :-------                                  | :----------                   |
| /cas/v1/tickets                           | Authentication                |
| /search/version                           | Retrieves <abbr title="Concept Unique Identifier">CUI</abbr> when searching by term or code|
| /content/version/CUI                      | Retrieves information about a known <abbr title="Concept Unique Identifier">CUI</abbr>|

## Exported Functions

The following functions access the above enpoints. See the [method documentation](#Methods-1) for specific usage.

| Function                                | Description                   | 
| :-------                                | :----------                   |
| [`get_tgt`](#get-ticket-granting-ticket)| Get a ticket-granting ticket  |
| [`search_umls`](#search-umls)           | Search UMLS Rest API          |
| [`best_match_cui`](#best-cui)           | Return concept ID of best match for a serach|
| [`get-cui`](#search-based-on-cui)       | Get information associated with a Concept ID (<abbr title="Concept Unique Identifier">CUI</abbr>)|
| [`get_semantic_types`](#semantic-types) | Retrieve smenatic types associated with a <abbr title="Concept Unique Identifier">CUI</abbr>|

## Sample workflow

Service tickets are needed each time you search or retrieve content from the UMLS REST API. A service ticket is retrieved automatically by this software from a **ticket granting ticket**. Thus, the first step of your workflow must start by requesting a **ticket granting ticket** using your credentials. There are two ways you can do this:

**1. Use username and password**
```julia
    user = "myuser"
    psswd = "mypsswd"
    tgt = get_tgt(username=user, password=psswd)
```

**2. Use API KEY**
```julia
    apikey = "myapikey"
    tgt = get_tgt(apikey=apikey)
```

According to the UMLS documentation, **ticket granting tickets** are valid for 8 hours, therefore we locally store the ticket in a file and reuse it as long as it has not expired. If you get errors, you can force the `get_tgt` function to get a new ticket. For instance:

```julia
   tgt = get_tgt(force_new=true, apikey=apikey)
```

After authentication, you can query the <abbr title="Concept Unique Identifier">CUI</abbr> associated with a term (e.g obesity) to get the semantic type(s) associated with that term (e.g obesity is a Disease or Syndrome)

```julia
    term = "obesity"
    query = Dict("string"=>term, "searchType"=>"exact" )
    all_results= search_umls(tgt, query)
    cui = best_match_cui(all_results)   # cui="C0028754"
    sm = get_semantic_types(tgt, cui)   # sm[1] == "Disease or Syndrome"
```

**Options for searchType**

* Word: breaks a search term into its component parts, or words, and retrieves all concepts containing any of those words. For example: If you enter "Heart Disease, Acute" a Word search will retrieve all concepts containing any of the three words (heart, or disease, or acute). Word is the default Search Type selection and is appropriate for both English and non-English search terms.
* Approximate Match: applies lexical variant generation (LVG) rules to the search term and generally results in expanded retrieval of concepts. For example, a search for the term "cold" retrieves all concepts that contain any of the following words: COLDs, chronic obstructive lung disease, chronic obstructive lung diseases, cold, colder, coldest.
* Exact Match: retrieves only concepts that include a synonym that exactly matches the search term.
* Normalized String: use with English language terms only. Removes lexical variations such as plural and upper case text and compares search terms to the Metathesaurus normalized string index to retrieve relevant concepts.
* Normalized Word: use with English language terms only. Removes lexical variations such as plural and upper case text, and compares search terms to the Metathesaurus normalized word index to retrieve relevant concepts.
* Right Truncation: retrieves concepts with synonyms that begin with the letters of the search term. For example, a right truncation search for "bronch" retrieves concepts that contain synonyms such as bronchitis, bronchiole, bronchial artery.
* Left Truncation: retrieves concepts with synonyms that end with the letters of the search term. For example, a left truncation search for "itis" retrieves concepts that contain synonyms such as colitis, bronchitis, pancreatitis.

## Methods

```@docs
 get_tgt(; force_new::Bool = false, kwargs...)
```
--------------------------------------------------

```@docs
search_umls(tgt, query; version::String="current", timeout=1)
```
--------------------------------------------------

```@docs
 best_match_cui(result_pages)
```
--------------------------------------------------

```@docs
 get_cui(tgt,cui)
```
--------------------------------------------------

```@docs
get_semantic_types(tgt, cui; version="current")
```
--------------------------------------------------
