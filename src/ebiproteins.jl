# EBI Proteins
# ======
#
# APIs for EBI Proteins (UniProt)
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
EBI Proteins module.

The `EBIProteins` module provides a programming interface to the Uniprot
databases at EMBL-EBI. Ten functions are exported from this module:
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

Note: size = -1 allows all results to be streamed; this is not currently
implemented.
"""
module EBIProteins

export
    ebiproteins,
    ebifeatures,
    ebivariation,
    ebiproteomics,
    ebiantigen,
    ebiproteomes,
    ebigenecentric,
    ebitaxonomy,
    ebicoordinates,
    ebiuniparc

import XMLDict
import JSON
import HTTP
import BioServices.request

const baseURL = "https://www.ebi.ac.uk/proteins/api/"


# APIs of UniProt Proteins
# -------------------

"""
    ebiproteins(params...)

Retrieve protein data.

Calls the endpoint specified by "<operation>/<accession>/<subset>". If any argument is
unset it will be excluded.

If `dbtype` and `dbid` are set, calls the endpoint "<dbtype>:<dbid>".

If any query parameters are provided, calls the base endpoint.

Key Parameters: contenttype, operation, accession, subset, dbtype, dbid

`contenttype` may be "text/x-fasta", "text/x-flatfile", "application/json", "application/xml"

Query Parameters: offset, size, reviewed, isoform, goterms, keywords, ec, gene, exact_gene,
protein, organism, taxid, pubmed, seqLength, md5

"""
function ebiproteins(; contenttype = nothing, accession = nothing, operation = nothing, subset = nothing,
                  dbtype = nothing, dbid = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "proteins"
    if !isnothing(dbtype) || !isnothing(dbid)
        all(!isnothing, [dbid, dbtype]) || throw(ArgumentError("Both `dbtype` and `dbid` must be set."))
        path *= "/" * HTTP.escapeuri(dbtype) * ":" * HTTP.escapeuri(dbid)
    elseif isempty(params)
        any(!isnothing, [operation, accession, subset]) || throw(ArgumentError("At least one parameter must be set."))
        if !isnothing(operation)
            path *= "/" * HTTP.escapeuri(operation)
        end
        if !isnothing(accession)
            path *= "/" * HTTP.escapeuri(accession)
        end
        if !isnothing(subset)
            path *= "/" * HTTP.escapeuri(subset)
        end
    elseif !isnothing(accession)
        params[:accession] = string(accession)
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebifeatures(params...)

Retrieve protein data.

Calls the endpoint at "<accession>".

If `type` is set, calls the endpoint "type/<type>".

If any query parameters other than `categories` or `types` are provided,
or `accession` is not set, calls the base endpoint.

Key Parameters: contenttype, type, accession

`contenttype` may be "text/x-gff", "application/json", "application/xml"

Query Parameters: offset, size, reviewed, gene, exact_gene, protein,
organism, taxid, categories, types, terms
"""
function ebifeatures(; contenttype = nothing, accession = nothing, type = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "features"
    !isnothing(type) && !isnothing(accession) && throw(ArgumentError("Cannot set both `type` and `accession`"))
    if !isnothing(type)
        haskey(params, :terms) && params[:terms] != "" || throw(ArgumentError("At least one term is required."))
        path *= "/type/" * HTTP.escapeuri(type)
    elseif !isnothing(accession) && isempty(filter(kv -> first(kv) ∉ [:categories, :types], params))
        path *= "/" * HTTP.escapeuri(accession)
    elseif isnothing(accession) && isempty(params)
        throw(ArgumentError("At least one parameter must be set."))
    elseif !isnothing(accession)
        params[:accession] = string(accession)
    else
        any(haskey.(Ref(params), [:gene, :protein, :exact_gene, :organism, :taxid])) ||
            throw(ArgumentError("Must set at least one of `gene`, `exact_gene`, `protein`, `organism`, or `taxid`."))
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebivariation(params...)

Retrieve variant data.

Calls the endpoint at "<accession>".

If `dbid` is set, calls the endpoint "dbsnp/<dbid>".

If `hgvs` is set, calls the endpoint "hgvs/<hgvs>".

If any query parameters other than `sourcetype`, `consequencetype`,
`wildtype`, `alternativesequence`, or `location` are provided,
or `accession` is not set, calls the base endpoint.

Key Parameters: contenttype, accession, dbid, hgvs

`contenttype` may be "text/x-gff", "text/x-peff", "application/json", "application/xml"

Query Parameters: offset, size, sourcetype, consequencetype, wildtype,
alternativesequence, location, disease, omim, evidence, taxid, dbtype, dbid
"""
function ebivariation(; contenttype = nothing, accession = nothing, dbid = nothing, hgvs = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "variation"
    !isnothing(dbid) && !isnothing(hgvs) && throw(ArgumentError("Cannot set both `dbid` and `hgvs`"))
    if !isnothing(dbid)
        path *= "/dbsnp/" * HTTP.escapeuri(dbid)
    elseif !isnothing(hgvs)
        path *= "/hgvs/" * HTTP.escapeuri(hgvs)
    elseif !isnothing(accession) && isempty(filter(kv -> first(kv) ∉ [:sourcetype, :consequencetype, :wildtype, :alternativesequence, :location], params))
        path *= "/" * accession
    elseif isnothing(accession) && isempty(params)
        throw(ArgumentError("At least one parameter must be set."))
    elseif !isnothing(accession)
        params[:accession] = string(accession)
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebiproteomics(params...)

Retrieve proteomics data.

Calls the endpoint at "<accession>".

If any query parameters are set or `accession` is not set, calls the base endpoint.

Key Parameters: contenttype, accession

`contenttype` may be "text/x-gff", "application/json", "application/xml"

Query Parameters: offset, size, taxid, upid, datasource, peptide, unique
"""
function ebiproteomics(; contenttype = nothing, accession = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "proteomics"
    if isempty(params)
        isnothing(accession) && throw(ArgumentError("At least one term is required."))
        path *= "/" * HTTP.escapeuri(accession)
    elseif !isnothing(accession)
        params[:accession] = string(accession)
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebiantigen(params...)

Retrieve proteomics data.

Calls the endpoint at "<accession>"

If any query parameters are set or `accession` is not set, calls the base endpoint.

Key Parameters: contenttype, accession

`contenttype` may be "text/x-gff", "application/json", "application/xml"

Query Parameters: offset, size, antigen_sequence, antigen_id, ensembl_ids, match_score
"""
function ebiantigen(; contenttype = nothing, accession = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "antigen"
    if isempty(params)
        isnothing(accession) && throw(ArgumentError("At least one term is required."))
        path *= "/" * HTTP.escapeuri(accession)
    elseif !isnothing(accession)
        params[:accession] = string(accession)
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebiproteomes(params...)

Retrieve proteome data.

Calls the endpoint at "<operation>/<upid>". If any argument is unset it will be excluded.

If any other query parameters are set or `upid` is not set, calls the base endpoint.

Key Parameters: contenttype, upid, reviewed

`contenttype` may be "application/json", "application/xml"

Query Parameters: offset, size, upid, name, taxid, keyword, xref, genome_acc,
is_ref_proteome, is_redundant, reviewed
"""
function ebiproteomes(; contenttype = nothing, operation = nothing, upid = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "proteomes"
    if isempty(filter(kv -> first(kv) != :reviewed, params))
        !isnothing(upid) || throw(ArgumentError("Must set `upid`"))
        if !isnothing(operation)
            path *= "/" * HTTP.escapeuri(operation)
        end
        path *= "/" * HTTP.escapeuri(upid)
    elseif !isnothing(upid)
        params[:upid] = HTTP.escapeuri(string(upid))
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebigenecentric(params...)

Retrieve proteomics data.

Calls the endpoint at "<accession>"

If any query parameters are set or `accession` is not set, calls the base endpoint.

Key Parameters: contenttype, accession

`contenttype` may be "application/json", "application/xml"

Query Parameters: offset, size, upid, gene
"""
function ebigenecentric(; contenttype = nothing, accession = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "genecentric"
    if isempty(params)
        isnothing(accession) && throw(ArgumentError("At least one term is required."))
        path *= "/" * HTTP.escapeuri(accession)
    elseif !isnothing(accession)
        params[:accession] = HTTP.escapeuri(string(accession))
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebitaxonomy(params...)

Retrieve taxonomy data.

Calls the endpoint at "<operation>/<ids>/<subset>". If `getnode` is true, calls the endpoint
at "<operation>/<ids>/<subset>/node". If any argument is unset it will be excluded.

If `operation` is "path" or "relationship", calls those respective endpoints: "path", "path/nodes",
"relationship".

Key Parameters: contenttype, operation, ids, subset

`contenttype` may be "application/json", "application/xml"

Query Parameters: pageNumber, pageSize, searchType, fieldName, depth, direction, from, to
"""
function ebitaxonomy(; contenttype = nothing, operation = nothing, ids = nothing, subset = nothing,
                     getnode = false, params...)
    params = process_parameters(params)
    !isnothing(operation) || throw(ArgumentError("Must set `operation`."))
    path = baseURL * "taxonomy/" * HTTP.escapeuri(operation)
    if operation == "path"
        haskey(params, :direction) || throw(ArgumentError("Must set `direction`."))
        !isnothing(ids) || throw(ArgumentError("Must set `ids`."))
        params[:id] = HTTP.escapeuri(string(ids))
        if getnode
            path *= "/nodes"
        end
    elseif operation == "relationship"
        haskey(params, :from) && haskey(params, :to) || throw(ArgumentError("Must set `from` and `to`."))
    else
        !isnothing(ids) || throw(ArgumentError("Must set `ids`."))
        path *= "/" * HTTP.escapeuri(string(ids))
        if !isnothing(subset)
            path *= "/" * HTTP.escapeuri(subset)
        end
        if getnode
            path *= "/node"
        end
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebicoordinates(params...)

Retrieve coordinates data.

If `accession` is set, calls the endpoint at "<accession>". If a position is also provided,
calls the endpoint at either "location/<accession>:<pPosition>" or "location/<accession>:<pStart>-<pEnd>".

If `dbtype` and `dbid` are provided, calls the endpoint at "<dbtype>:<dbid>".

If `taxonomy` and `locations` are provided, calls the endpoint at "<taxonomy>/<locations>". If `getfeature`
is true, access the endpoint at "<taxonomy>/<locations>/feature".

If any query parameters not approptiate to the specific endpoint are set, calls the base endpoint.

Key Parameters: contenttype, accession, dbtype, dbid, pPosition, pEnd, taxonomy, locations, getfeature

`contenttype` may be "application/json", "application/xml"

Query Parameters: offset, size, in_range
"""
function ebicoordinates(; accession = nothing, dbtype = nothing, dbid = nothing, pPosition = nothing,
                        pStart = nothing, pEnd = nothing, locations = nothing, taxonomy = nothing,
                        getfeature = false, contenttype = nothing, params...)
    params = process_parameters(params)
    path = baseURL * "coordinates"
    if !isnothing(accession) && isempty(params)
        isnothing(dbtype) && isnothing(dbid) && isnothing(taxonomy) && isnothing(locations) ||
            throw(ArgumentError("Cannot set `dbtype`, `dbid`, `taxonomy`, or `locations` with `accession`."))
        path *= "/"
        if !isnothing(pPosition) || !isnothing(pStart)
            isnothing(pStart) && isnothing(pEnd) || (pPosition = pStart)
            path *= "location/" * HTTP.escapeuri(accession) * ":" * HTTP.escapeuri(pPosition)
            if !isnothing(pEnd)
                path *= "-" * HTTP.escapeuri(pEnd)
            end
        else
            path *= HTTP.escapeuri(accession)
        end
    elseif !isnothing(dbtype) || !isnothing(dbid)
        isnothing(accession) && isnothing(taxonomy) && isnothing(locations) ||
            throw(ArgumentError("Cannot set `accession`, `taxonomy`, or `locations` with `dbtype` and `dbid`."))
        all(!isnothing, [dbid, dbtype]) || throw(ArgumentError("Both `dbtype` and `dbid` must be set."))
        path *= "/" * HTTP.escapeuri(dbtype) * ":" * HTTP.escapeuri(dbid)
    elseif !isnothing(taxonomy) || !isnothing(locations)
        isnothing(accession) ||
            throw(ArgumentError("Cannot set `accession` with `taxonomy` and `locations`."))
        all(!isnothing, [taxonomy, locations]) || throw(ArgumentError("Both `taxonomy` and `locations` must be set."))
        path *= "/" * HTTP.escapeuri(taxonomy) * "/" * HTTP.escapeuri(locations)
        getfeature && (path *= "/feature")
    elseif !isnothing(accession)
        params[:accession] = HTTP.escapeuri(string(accession))
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

"""
    ebiuniparc(params...)

Retrieve proteomics data.

Calls the endpoint at "accession/<accession>", "dbreference/<dbid>", "uniparc/upi/<upi>",
or "sequence", depending on provided values.

If `bestguess` is true, calls the endpoint at "bestguess".

If any excess query parameters are set for the specific endpoint, calls the base endpoint.

Key Parameters: contenttype, accession, upid, upi, dbid, sequence, sequencecontenttype,
bestguess

`contenttype` may be "text/x-fasta", "application/json", "application/xml"

`sequencecontenttype` may be "text/plain" (default), "application/json", "application/xml", if set

Query Parameters: offset, size, dbtype, gene, protein, taxid, organism, sequencechecksum,
ipr, signaturetype, signatureid, seqLength, rdDdtype, rfDbid, rfActive, rfTaxId
"""
function ebiuniparc(; contenttype = nothing, accession = nothing, dbid = nothing, upid = nothing,
                    upi = nothing, sequence = nothing, sequencecontenttype = "text/plain", bestguess = false,
                    params...)
    params = process_parameters(params)
    path = baseURL * "uniparc"
    if !isnothing(sequence)
        path *= "/sequence"
        header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype, "Content-Type" => sequencecontenttype]
        body = HTTP.escapeuri(sequence)
        return request("POST", path, body = body, header, query = params, retry_non_idempotent = true)
    elseif !isnothing(accession) && isempty(filter(kv -> first(kv) ∉ [:rfDdtype, :rfDbid, :rfActive, :rfTaxId], params))
        path *= "/accession/" * HTTP.escapeuri(accession)
    elseif !isnothing(upid) && isempty(filter(kv -> first(kv) ∉ [:offset, :size, :rfDdtype, :rfDbid, :rfActive, :rfTaxId], params))
        path *= "/proteome/" * HTTP.escapeuri(upid)
    elseif !isnothing(dbid) && isempty(filter(kv -> first(kv) ∉ [:offset, :size, :rfDdtype, :rfDbid, :rfActive, :rfTaxId], params))
        path *= "/dbreference/" * HTTP.escapeuri(dbid)
    elseif !isnothing(upi) && isempty(filter(kv -> first(kv) ∉ [:rfDdtype, :rfDbid, :rfActive, :rfTaxId], params))
        path *= "/upi/" * HTTP.escapeuri(upi)
    elseif bestguess
        path *= "/bestguess"
    else
        isnothing(accession) || (params[:accession] = HTTP.escapeuri(accession))
        isnothing(upid) || (params[:upid] = HTTP.escapeuri(upid))
        isnothing(dbid) || (params[:dbid] = HTTP.escapeuri(dbid))
        isnothing(upi) || (params[:upi] = HTTP.escapeuri(upi))
    end
    header = isnothing(contenttype) ? Pair{String, String}[] : ["Accept" => contenttype]
    return request("GET", path, header, query = params)
end

# Process query parameters.
function process_parameters(params)
    # stringify all values
    params = Dict{Symbol, Any}(params)
    for (key, val) in params
        params[key] = string(val)
    end

    return params
end

if VERSION < v"1.1"
isnothing(x) = x === nothing
end

end
