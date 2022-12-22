require 'csv'
require 'set'
require 'uri'
require 'net/http'
require 'json'

# For each opus in a file, query for identifiers of a particular type


def get_id_groups(filename, id_type)
  #Read the file
  
  var_name = (id_type == "isbn")? "isbns": "lccns"
  CSV.foreach(filename, headers: true) do |row|
    #Each row is the OPUS URI   
    #puts row.to_s
    # Query
    opus = row.to_s.strip
    query = (id_type == "isbn")? get_isbn_query(opus): get_lccn_query(opus)
    #puts query
    results = execute_query(query)
    if(has_results(results))
      puts get_result_string(results, var_name)
      #puts results.to_s
    end
  end
end

#Generate query to get all ISBNs for that row
def get_isbn_query(opus)
  return "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " + 
  "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> " + 
  "PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> " + 
  "SELECT  (group_concat(DISTINCT ?isbn;separator=',') AS ?isbns) WHERE {" + 
	"<" + opus + "> bf:hasExpression ?work1 ." +  
	"?work1 bf:hasInstance ?instance1 ." + 
	"?instance1 bf:identifiedBy ?id1 ." + 
	"?id1 rdf:type bf:Isbn ." + 
	"?id1 rdf:value ?isbn .}";
end

def get_lccn_query(opus)
  return "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " + 
  "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> " + 
  "PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> " + 
  "SELECT  (group_concat(DISTINCT ?lccn;separator=',') AS ?lccns) WHERE {" + 
	"<" + opus + "> bf:hasExpression ?work1 ." +  
	"?work1 bf:hasInstance ?instance1 ." + 
	"?instance1 bf:identifiedBy ?id1 ." + 
	"?id1 rdf:type bf:Lccn ." + 
	"?id1 rdf:value ?lccn .}";
end

#Execute a given query

def execute_query(query)
  # Insert the URL of your Fuseki server 
  uri = URI.parse("[Fuseki server SPARQL endpoint URL]")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/sparql-results+json, application/rdf+json, application/json"
  request.set_form_data(
    "query" => query,
  )
  response = Net::HTTP.start(uri.hostname, uri.port, {}) do |http|
    http.request(request)
  end
  #puts response.body
  return JSON.parse(response.body)
end

def has_results(query_result)
  return (query_result.key?("results") && query_result["results"].key?("bindings") && query_result["results"]["bindings"].length > 0)
end

#For query result that exists, get all binding results back, technically this should just be one result for the queries in this file
def get_result_string(query_result, var)
  bindings = query_result["results"]["bindings"]
  isbn_list = bindings.map do |binding|
    if binding.key?(var) && binding[var].key?("value")
      binding[var]["value"]
    end
  end
  #puts isbn_list.length.to_s
  return isbn_list.join(",")
end

# Get ISBNs under the same opus, using the file that lists all opera that have at least two different works which link to instances with ISBNs
#get_id_groups("opusqueryresults.csv","isbn");
# Get LCCNs under the same opus, using the file that lists all opera that have at lesat two different works which link to instances with LCCNs
#"opuslccnqueryresults.csv"
# "testlccnresults.csv"
get_id_groups("opuslccnqueryresults.csv","lccn");
