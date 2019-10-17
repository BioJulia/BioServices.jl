```@meta
CurrentModule = BioServices
```

# bioDBnet

[bioDBnet](https://biodbnet-abcc.ncifcrf.gov/) provides REST APIs to access its 7 core services and 3 utility services. This module implements
functions to utilize these APIs from within julia. 

| Function    | Description                                                                |
| :-------    | :----------                                                                |
| `db2db`     | Map identifiers from one database to their identifiers in another database.                 |
| `dbwalk`   | Same as db2db, but the traversal path between nodes is specified manually.                             |
| `dbfind`     | Same as db2db, but attempts to automatically identify the source database.              |
| `dbreport`  | Map an ID from one database to all other databases when available.                             |
| `db_ortho`    | Convert IDs from one species to orthologous identifiers in another species.                        |
| `db_annot`     | Obtain annotation terms for an identifier.                         |
| `list_annot`   | Return all available annotation terms. |
| `get_inputs`    | Get all input nodes in bioDBnet.                                             |
| `get_pathways` | Get all available pathways in bioDBnet    |
| `outputs_for_inputs` | Get all possible output nodes for a given input node.    |
| `dir_outputs_for_inputs` | Get all direct output nodes for a given input node.    |

Similar to eutils.jl, all methods in this module operate on keyword parameters. 

Consistency across function in keyword meanings has been attempted:

| Keyword    | Description                                                                |
| :-------    | :----------                                                                |
| `input`     | The name of the database that an identifier hails from. Singular, because only one input database is allowed.                 |
| `output`   | The name of the database that you wish to map an identifier to. Singular, because only one output is allowed in some instances.                            |
| `outputs`     | Same as `output`, except multiple output databases can be specified.              |
| `values`  | The identifiers that you wish to send to the REST API.                       |
| `taxonid`     | Optional, the NCBI Taxon ID of the organism you want to search within                         |
| `rettype`   | Optional, either 'xml' or 'json'. Default: 'xml' |

Specific methods have other required parameters specified in the documentation. 

Also similar to eutils, a `Response` object is returned by all functions. This response object contains either xml or json, depending on
what value `rettype` was given. This is contained within the field `body` of the object.

An example of using db2db to convert a DrugBankId to a KeggDrugID
```jlcon
julia> using BioServices.bioDBnet # import the module

# Convert the DrugBank Drug ID "DB00316" (aspirin) to its KeggDrugID and return it as JSON.
julia> res = bioDBnet.db2db(input="DrugBankDrugId", outputs = ["KeggDrugId"], 
                        values = ["DB00316"], rettype="json")

```
the `res` object of type Response contains:

```
HTTP.Messages.Response:
"""
HTTP/1.1 200 OK
Date: Thu, 17 Oct 2019 01:15:38 GMT
Server: Apache
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Cache-Control: no-cache, must-revalidate
Expires: 0
X-Powered-By: Luracast Restler v3.0.0rc3
Content-Language: en
X-Frame-Options: sameorigin
Access-Control-Allow-Origin: *
Content-Length: 81
Content-Type: application/json; charset=utf-8

[
    {
        "InputValue": "DB00316",
        "KEGG Drug ID": "D00217"
    }
]"""
```

And you can parse the resulting JSON output contained in res.body using the JSON module:

```jlcon
julia> body = JSON.parse(string(res.body))
```
Returning:
```
1-element Array{Any,1}:
 Dict{String,Any}("InputValue" => "DB00316","KEGG Drug ID" => "D00217")
```
Working with XML is effectively the same, with the exception of how you parse the output.
For this, I recommend [XMLDict](https://github.com/JuliaCloud/XMLDict.jl).

```jlcon
julia> using BioServices.bioDBnet # import the module

# Convert the DrugBank Drug ID "DB00316" (aspirin) to its KeggDrugID and return it as JSON.
julia> res = bioDBnet.db2db(input="DrugBankDrugId", outputs = ["KeggDrugId"], 
                        values = ["DB00316"], rettype="xml")
```
the `res` object contains:
```
HTTP.Messages.Response:
"""
HTTP/1.1 200 OK
Date: Thu, 17 Oct 2019 01:24:33 GMT
Server: Apache
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Cache-Control: no-cache, must-revalidate
Expires: 0
X-Powered-By: Luracast Restler v3.0.0rc3
Content-Language: en
Vary: Accept-Encoding
X-Frame-Options: sameorigin
Access-Control-Allow-Origin: *
Content-Length: 137
Content-Type: application/xml; charset=utf-8

<?xml version="1.0"?>
<response>
  <item>
    <InputValue>DB00316</InputValue>
    <KEGGDrugID>D00217</KEGGDrugID>
  </item>
</response>
"""
```

Which you can parse like so:

```
julia> body = XMLDict.parse_xml(String(res.body))

XMLDict.XMLDictElement with 1 entry:
  "item" => EzXML.Node(<ELEMENT_NODE[item]@0x0000000006a1da60>)
```
[EzXML](https://github.com/bicycle1885/EzXML.jl) provides documentation on how to work with XML Nodes in Julia. 
