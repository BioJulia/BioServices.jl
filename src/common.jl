import HTTP

# create and handle an HTTP request
function request(method::String, URL::String, headers::Vector{Pair{String, String}} = Pair{String, String}[]; params...)
    exception = nothing

    # retry request up to four times
    for i in 1:4
        try
            return HTTP.request(method, URL, headers; status_exception=true, params...)
        catch e
            local found_header = false
            exception = e
            # here we find the Retry-After header and sleep for the specified amount of time
            if isa(e, HTTP.StatusError) && e.response.status == 429
                for (header, value) in e.response.headers
                    if (header == "Retry-After")
                        found_header = true
                        sleep(parse(Int, value))
                        break
                    end
                end

                # if the header wasn't found, sleep for 2 seconds
                if !found_header
                    sleep(2)
                end
            else
                # we only handle HTTP 429, so for any other status, throw the error
                rethrow
            end
        end
    end

    # if we get here, we should have run out of retries
    throw(exception)
end
