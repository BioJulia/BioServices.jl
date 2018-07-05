# GGGenome
# ======
#
# APIs for GGGenome.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/Bio.jl/blob/master/LICENSE.md

"""
GGGenome module.
The `GGGenome` module provides a programming interface to GGGenome, 
a ultrafast DNA sequence search service, hosted by DBCLS.
Two functions are exported from this module:
1. `gggenome`: DNA sequence search
2. `gggenome_dblist`: List of available databases
See "GGGenome Help" (https://gggenome.dbcls.jp/en/help.html) for more details.
"""
module GGGenome

export
    gggsearch,
    gggdbs


import HTTP

const baseURL = "https://gggenome.dbcls.jp/"
const dblistURL = "https://raw.githubusercontent.com/meso-cacase/GGGenome/master/DBlist.pm"


# APIs of GGGenome
# -------------------

"""
    gggsearch(; params...)
Retrieve results of gggenome search of a query sequence.
Required parameters: 
	query		String. Nucleotide sequence, case insensitive.
Optional parameters:
	db			String. Target database name. hg19 if not specified.
				Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list
	k			Integer. Maximum number of mismatches/gaps. 0 if not specified.
	strand		 '+' ('plus') or '-' ('minus') to search specified strand only.
	format		[html|txt|csv|bed|gff|json]. html if not specified.
	timeout		Integer.
	output		"toString": String.
				"extractTopHit": Extract top hit as String. (Currently, only works with format="txt")
				Otherwise: A HTTP.Messages.Response object is returned.
	show_url	If true, print URL of REST API.
"""
function gggsearch(; timeout=5, params...)
	params = Dict(params)
	url = generate_url(params)
	if haskey(params, :show_url) && params[:show_url] == true
		println(url)
	end
	res = HTTP.request("GET", url, timeout=timeout)

	if haskey(params, :output)
		if params[:output] == "toString"
			return gggenomeToString(res)
		elseif params[:output] == "extractTopHit" && haskey(params, :format) && params[:format] == "txt"
			return extractTopHit(gggenomeToString(res))
		else
			return res
		end
	else
		return res
	end
end

# function gggenome_base(; timeout=5, params...)
# 	params = Dict(params)
# 	return HTTP.request("GET", generate_url(params), timeout=timeout)
# end

function gggenomeToString(res::HTTP.Messages.Response)
	return String(res.body)
end

function extractTopHit(res_str::String)
	topResult = "No hit"
	for ln in split(chomp(res_str), "\n")
		if ln[1] == '#'
			continue
		else
			topResult = String(chomp(ln))
			break
		end
	end
	return(topResult)
end


"""
    gggdbs()
Retrieve full list of available databases.
Full list of databases: https://gggenome.dbcls.jp/en/help.html#db_list.
"""
function gggdbs()
	res = HTTP.request("GET", dblistURL)
	arr = split(String(res.body), "\n")
	index_l = 0
	index_r = 0
	for i in 1:length(arr)
		if startswith("<<'--EOS--' ;", arr[i])
			index_l = i + 1
		elseif startswith("--EOS--", arr[i])
			index_r = i - 1
			break
		end
	end
	return arr[index_l:index_r]
end

function generate_url(params)
	url = baseURL
	if haskey(params, :db)
		url *= params[:db] * "/"
	end

	if haskey(params, :k)
		url *= string(params[:k]) * "/"
	end

	if haskey(params, :strand)
		url *= params[:strand] * "/"
	end

	if haskey(params, :query)
		url *= params[:query]
	end

	if haskey(params, :format)
		url *= "." * params[:format]
	end

	return(url)
end


end