# EBI Proteins (actually not clear what the right way to refer to it is)
# ======
#
# APIs for EBI Proteins (UniProt)
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
EBI Proteins module.

The `EBIProteins` module provides a programming interface to the Uniprot
databases at EMBL-EBI. Nine functions are exported from this module:
1. `proteins`: protein sequences
2. `features`: functional annotations
3. `variation`: variation data
4. `proteomics`: proteomics datasets
5. `antigen`: antigens
6. `proteomes`: proteome data
7. `genecentric`: proteome data grouped by under a gene
8. `taxonomy`: taxonomic relationships
9. `coordinates`: genomic coordinates
10. `uniparc` : non-redundant protein sequences

See "EMBL-EBI Proteins API"
(https://www.ebi.ac.uk/proteins/api/doc/) for more details. The implemented
APIs are based on the document as of March 24, 2021.
"""
module EBIProteins

export
    proteins,
    features,
    set_context!

import XMLDict
import JSON
import HTTP

const baseURL = "https://www.ebi.ac.uk/proteins/api/"


# APIs of UniProt Proteins
# -------------------

"""
    proteins(ctx = Dict(); params...)

Retrieve protein data.

Calls the endpoint specified by "<operation>/<accession>/<subset>".

If `dbtype` and `dbid` are set, calls the endpoint "<dbtype>:<dbid>".

If any query parameters are provided, calls the base endpoint.

Key Parameters: contenttype, operation, accession, subset, dbtype, dbid

`contenttype` may be "text/x-fasta", "text/x-flatfile", "application/json", "application/xml"

Query Parameters: offset, size, reviewed, isoform, goterms, keywords, ec, gene, exact_gene,
protein, organism, taxid, pubmed, seqLength, md5

"""
function proteins(contenttype = nothing, accession = nothing, operation = nothing, subset = nothing,
                  dbtype = nothing, dbid = nothing, params...)
    params = process_parameters(params, ctx)
    path = baseURL * "proteins"
    if !isnothing(dbtype) || !isnothing(dbid)
        all(!isnothing, [dbid, dbtype]) || throw(ArgumentError("Both `dbtype` and `dbid` must be set."))
        path *= "/" * dbtype * ":" * dbid
    elseif isempty(params)
        path *= "/"
        any(!isnothing, [operation, accession, subset]) || throw(ArgumentError("At least one parameter must be set."))
        if !isnothing(operation)
            path *= operation * "/"
        end
        if !isnothing(accession)
            path *= accession
        end
        if !isnothing(subset)
            path *= subset
        end
    else
        params[:accession] = string(accession)
    end
    header = isnothing(contenttype) ? [] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    features(ctx = Dict(); params...)

Retrieve protein data.

Calls the endpoint at "<accession>"

If `type` are set, calls the endpoint "type/<type>".

If any query parameters other than "categories" or "types" are provided,
calls the base endpoint.

Key Parameters: contenttype, type, accession

`contenttype` may be "text/x-gff", "application/json", "application/xml"

Query Parameters: offset, size, reviewed, gene, exact_gene, protein,
organism, taxid, categories, types, terms
"""
function features(contenttype = nothing, accession = nothing, type = nothing, params...)
    params = process_parameters(params, ctx)
    path = baseURL * "features"
    if !isnothing(type)
        haskey(params, :terms) && params[:terms] != "" || throw(ArgumentError("At least one term is required."))
        path *= "/type/" * type
    elseif !isnothing(accession) && isempty(filter(kv -> first(kv) ∉ ["categories", "types"], params))
        path *= "/" * accession
    elseif isnothing(accession) && isempty(params)
        throw(ArgumentError("At least one parameter must be set."))
    end
    header = isnothing(contenttype) ? [] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

function variation()
    error("Not implemented")
end

function proteomics()
    error("Not implemented")
end

function antigen()
    error("Not implemented")
end

function proteomes()
    error("Not implemented")
end

function genecentric()
    error("Not implemented")
end

function taxonomy()
    error("Not implemented")
end

function coordinates()
    error("Not implemented")
end

function uniparc()
    error("Not implemented")
end

# Process query parameters.
function process_parameters(params)
    # stringify all values
    for (key, val) in params
        params[key] = string(val)
    end

    return params
end

end
