# bioDBnet
# ======
#
# APIs for bioDBnet services
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
bioDBnet is the work of the Advanced Biomedical Computing Center at the
Federick National Laboratory for Cancer Research and the National Cancer
Institute at Frederick. It stores relational connections between many
biological databases and provides tools for querying these relations in
various ways.
"""

module bioDBnet

export
    db2db,
    dbwalk,
    dbreport,
    dbfind,
    db_ortho,
    db_annot,
    get_inputs,
    get_pathways,
    outputs_for_input,
    dir_outputs_for_input

import XMLDict
import JSON
import HTTP


const baseURLjson =
"https://biodbnet-abcc.ncifcrf.gov/webServices/rest.php/biodbnetRestApi.json"

const baseURLxml =
"https://biodbnet-abcc.ncifcrf.gov/webServices/rest.php/biodbnetRestApi.xml"

# APIs for bioDBnet
# -------------------

"""
    db2db(;input::AbstractString, outputs::Array{String,1},
    values::Array{String,1}; params...)

Link input DB Ids to output DB IDs

Parameters: input, output, params
"""
function db2db(; input::AbstractString, outputs::Array{String,1},
    values::Array{String, 1}, params...)
    # process parameters
    values = join([string(val) for val in values], ',')
    outputs = join([string(val) for val in outputs], ',')
    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    # construct a HTTP request
    if haskey(params, :taxonid)
        return(REST_call(string(lbaseURL, "?method=db2db&format=row",
                     "&input=", input,
                     "&inputValues=", values,
                     "&outputs=", outputs,
                     "&taxonId=", params[:taxonid])))
    else
        return(REST_call(string(lbaseURL, "?method=db2db&format=row",
                     "&input=", input,
                     "&inputValues=", values,
                     "&outputs=", outputs)))
    end
end


"""
    dbwalk(values::AbstractString, db_path::Array{String,1}; params...)

Control the path of linking an ID in one database to another by specifying a
node-walk order.

Parameters: values, db_path, params
"""
function dbwalk(; values::Array{String, 1}, db_path::Array{String, 1},
    params...)

    # process parameters
    values = join([string(val) for val in values], ',')
    db_path = join([string(node) for node in db_path], "-%3E")
    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    if haskey(params, :taxonid)
        return(REST_call(string(lbaseURL, "?method=dbwalk&format=row",
        "&inputValues=", values,
        "&dbPath=", db_path,
        "&taxonId=", params[:taxonid])))
    else
        return(REST_call(string(lbaseURL, "?method=dbwalk&format=row",
        "&inputValues=", values,
        "&dbPath=", db_path)))
    end
end


"""
    dbreport(input::AbstractString, values::Array{String, 1}; params...)

Link a set of IDs from one database to all other available databases.

Parameters: input, values, params
"""
function dbreport(; input::AbstractString, values::Array{String, 1}, params...)
    # process parameters
    values = join([string(val) for val in values], ',')

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    # construct a HTTP request
    if haskey(params, :taxonid)
        return(REST_call(string(lbaseURL, "?method=dbreport&format=row",
                     "&input=", input,
                     "&inputValues=", values,
                     "&taxonId=", params[:taxonid])))
    else
        return(REST_call(string(lbaseURL, "?method=dbreport&format=row",
                     "&input=", input,
                     "&inputValues=", values)))
    end
end


"""
    dbfind(values::Array{String, 1}, output::Array{String, 1}; params...)

Attempts to automatially identify the source database for given inputs and
links to requested output database.

Parameters: values, output, params
"""
function dbfind(; values::Array{String, 1}, output::AbstractString, params...)

    # process parameters
    values = join([string(val) for val in values], ',')
    output = join([string(val) for val in output], ',')

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    if haskey(params, :taxonid)
        return(REST_call(string(lbaseURL, "?method=dbfind&format=row",
        "&inputValues=", values,
        "&output=", output,
        "&taxonId=", params[:taxonid])))
    else
        return(REST_call(string(lbaseURL, "?method=dbfind&format=row",
        "&inputValues=", values,
        "&output=", output)))
    end
end


"""
    db_ortho(input::AbstractString, values::Array{String, 1},
            in_taxon::AbstractString, out_taxon::AbstractString,
            output::AbstractString)

Convert identifiers in one species to identifiers in another species.

Parameters: input, values, in_taxon, out_taxon, output; params
"""
function db_ortho(; input::AbstractString, values::Array{String, 1},
                  in_taxon::AbstractString, out_taxon::AbstractString,
                  output::AbstractString, params...)

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    # process parameters
    values = join([string(val) for val in values], ',')
    output = join([string(val) for val in output], ',')

    return(REST_call(string(baseURL, "?method=dbortho&format=row",
                    "&input=", input,
                    "&inputValues=", values,
                    "&inputTaxon=", in_taxon,
                    "&outputTaxon=", out_taxon,
                    "&output=", output)))
end


"""
    db_annot(values::Array{String, 1}, annotations::Array{String, 1};
            params...)

Obtain annotations for DB identifiers.

Parameters: values, annotations, params
"""
function db_annot(; values::Array{String, 1}, annotations::Array{String, 1},
                 params...)

    # process parameters
    values = join([string(val) for val in values], ',')
    annotations = join([string(ann) for ann in annotations], ",")

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    # construct a HTTP request
    if haskey(params, :taxonid)
        return(REST_call(string(baseURL, "?method=dbreport&format=row",
                     "&inputValues=", values,
                     "&annotations=", annotations,
                     "&taxonId=", params[:taxonid])))
    else
        return(REST_call(string(baseURL, "?method=dbreport&format=row",
                     "&inputValues=", values,
                     "&annotations=", annotations)))
    end
end


"""
    get_inputs()

Get all input nodes in bioDBnet

Parameters: params
"""
function get_inputs(; params...)

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    return(REST_call(url=string(lbaseURL,"?method=getinputs")))
end


"""
    get_pathways(params...)

Get all available pathways from all databases

Parameters: params
"""
function get_pathways(; params...)

    # if no specific database provided, "1" means return all pathways
    if !haskey(params, :pathways)
        pathways = "1"
    end

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    if haskey(params, :taxonid)
        return(REST_call(string(lbaseURL, "?method=getpathways",
                        "&pathways=", pathways,
                        "&taxonId=", params[:taxonid])))
    else
        return(REST_call(string(lbaseURL, "?method=getpathways",
                        "&pathways=", pathways)))
    end
end


"""
    outputs_for_input(input::AbstractString; params...)

Gets all the possible output nodes for a given input node

Parameters: input; params
"""
function outputs_for_input(; input::AbstractString, params...)

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    return(REST_call(string(lbaseURL, "?method=getoutputsforinput&",
                            "&input=", input)))
end


"""
    dir_outputs_for_input(input::AbstractString)

Gets all the direct output nodes for a given input node (Outputs reachable
by single edge connection in the bioDBnet graph

Parameters: input, params
"""
function dir_outputs_for_input(; input::AbstractString, params...)

    local lbaseURL = nothing
    if haskey(params, :rettype)
        if params[:rettype] == "json"
            lbaseURL = baseURLjson
        elseif params[:rettype] == "xml"
            lbaseURL = baseURLxml
        else
            println("Invalid rettype. Valid options are 'xml' or 'json'.
                    Defaulting to json.")
            lbaseURL = baseURLjson
        end
    else
        lbaseURL = baseURLjson
    end

    return(REST_call(string(lbaseURL, "?method=getdirectoutputsforinput",
                            "&input=", input,
                            "&directOutput=1")))
end


# REST Call Driver Function
# -------------------

"""
    REST_call(url::AbstractString)

Perform an HTTP get request to a REST server. Supports get requests only.

Parameters: url
"""
function REST_call(url::AbstractString)
    exception = nothing
    for i in 1:4
        try
            return HTTP.request("GET", url)
        catch e
            # ---- adapted from eutils::request ---- #
            local found_header = false
            exception = e
            if isa(e, HTTP.StatusError) && e.response.status == 429
                for (header, value) in e.response.headers
                    if (header == "Retry-After")
                        found_header = true
                        sleep(parse(Int, value))
                        break
                    end
                end
                if !found_header
                    sleep(2)
                end
            else
                rethrow
            end
        end
    end

    throw(exception)
end


end
