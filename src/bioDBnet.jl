# bioDBnet
# ======
#
# APIs for bioDBnet services
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
TODO
"""

module bioDBnet

export
    db2db#,
    # dbwalk,
    # dbreport,
    # dbfind,
    # db_ortho,
    # db_annot,
    # db_org,
    # get_inputs,
    # getoutput_for_inp, # rename?
    # getdiroutp_for_inp, # rename?

import XMLDict
import JSON
import HTTP


const baseURL =
"https://biodbnet-abcc.ncifcrf.gov/webServices/rest.php/biodbnetRestApi.json"

# APIs for bioDBnet
# -------------------

"""
"""
function db2db(input::AbstractString, outputs::Array{String,1}, params::Dict{String, Any})
    # process parameters
    params["values"] = join([string(val) for val in params["values"]], ',')
    outputs = join([string(val) for val in outputs], ',')

    # construct a HTTP request
    if haskey(params, "taxonid")
        return(res = REST_call(string(baseURL,
                     "?method=db2db&format=row",
                     "&input=",
                     input,
                     "&inputValues=",
                     params["values"],
                     "&outputs=",
                     outputs,
                     "&taxonId=",
                     params["taxonid"])))
    else
        return(res = REST_call(string(baseURL,
                     "?method=db2db&format=row",
                     "&input=",
                     input,
                     "&inputValues=",
                     params["values"],
                     "&outputs=",
                     outputs)))
    end
end

function REST_call(url)
    println(url)
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
