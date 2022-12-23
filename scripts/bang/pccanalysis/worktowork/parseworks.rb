require 'csv'
require 'set'
require 'uri'
require 'net/http'
require 'json'

# Get unique predicates

def get_predicates
  set_mem_pred = Set.new
  # Key is one ISBN
  # value is also a hash representing other isbns
  # Test file: 'testworks.csv'
  # Actual file: 'relworks.csv'
  CSV.foreach('relworks.csv', headers: true) do |row|
          work1 = row[0]
          p = row[1]
          work2 = row[2]
          if ! (set_mem_pred.include?(p))
                  set_mem_pred.add(p)
          end
  end
  set_mem_pred.sort.each{|v| print v, "\n"}
end


# Generate new file with ISBN of work 1, property relating work 1 to work 2, and ISBN of work 2 
# If Work 2 does not have an ISBN, that row will be ignored
# Output: ISBN1|prop,ISBN2|prop2,ISBN3| --> {ISBN1: ["prop2,ISBN2", etc.
def get_isbns()
  #hash_mem = {}
  # Key is one ISBN
  # value is also a hash representing other isbns
  # Test file: 'testworks.csv'
  # Test file with just one row: 'testsinglework.csv'
  # Actual file: 'relworks.csv'
  CSV.foreach('relworks.csv', headers: true) do |row|
          work1 = row[0]
          p = row[1]
          work2 = row[2]
          #puts row.to_s
          #if ! (hash_mem.key?(work1))
          #        hash_mem[work1] = []
          #end
          #hash_mem[work1] << p.to_s + "," + work2.to_s
          result_str = check_work_isbns(work1, work2, p)
          if(result_str != "")
            puts result_str
          end
          
  end
  #hash_mem.each{|k,v| print k, "|", v.join("|"), "\n"}
end

def check_work_isbns(work1, work2, predicate)
  # First check if ISBN for work 2 exists
  #If it exists, then check ISBN for work 1
  # Assemble the string
  result_str = ""
  work1_isbns = ""
  work2_isbns = ""
  #query_result = query_for_isbns(work2)
  #query_result = query_for_instances(work2)
  query_result = query_for_isbn_instanceof(work2)
  #query_result = query_for_relationships(work2)
  if(has_results(query_result))
    #puts query_result.to_s
    rs = get_isbn_result_string(query_result)
    work2_isbns = rs.join(",")
    
    #Query for work 1
    w1_result = query_for_isbns(work1)
    rs2 = get_isbn_result_string(w1_result)
    work1_isbns = rs2.join(",")
    
    result_str = "[" + work1_isbns + "]|" + predicate + "|" + work2_isbns
    #puts result_str
    
  else 
    #puts work2
    #puts query_result.to_s
    #puts "No results for work"
  end
  
  return result_str
  
end

def has_results(query_result)
  return (query_result.key?("results") && query_result["results"].key?("bindings") && query_result["results"]["bindings"].length > 0)
end

#For query result that exists, get all ISBN values as comma delimited string
def get_isbn_result_string(query_result)
  bindings = query_result["results"]["bindings"]
  isbn_list = bindings.map do |binding|
    if binding.key?("isbn") && binding["isbn"].key?("value")
      #puts binding["isbn"]["value"]
      #return binding["isbn"]["value"]
      binding["isbn"]["value"]
    end
  end
  return isbn_list
end

#get_predicates() 
#get_isbns()

# execute against fuseki to get isbns for work1 and work2
def query_for_isbns(work)
  work_uri = "<" + work + ">"
 
  
  
  query="PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> SELECT DISTINCT ?isbn WHERE {" + work_uri + " bf:hasInstance ?instance1 .  ?instance1 bf:identifiedBy ?id1 . ?id1 rdf:type bf:Isbn . ?id1 rdf:value ?isbn . }"
  #puts query
  

  uri = URI.parse("http://localhost:3030/ds/sparql")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/sparql-results+json, application/rdf+json, application/json"
  request.set_form_data(
    "query" => query,
  )

  
  response = Net::HTTP.start(uri.hostname, uri.port, {}) do |http|
    http.request(request)
  end
  return JSON.parse(response.body)
# response.code
# response.body

 
end

def query_for_isbn_instanceof(work)
  work_uri = "<" + work + ">"
 
  
  
  query="PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> SELECT DISTINCT ?isbn WHERE {?instance1 bf:instanceOf " + work_uri + " .  ?instance1 bf:identifiedBy ?id1 . ?id1 rdf:type bf:Isbn . ?id1 rdf:value ?isbn . }"
  #puts query
  

  uri = URI.parse("http://localhost:3030/ds/sparql")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/json"
  request.set_form_data(
    "query" => query,
  )

  
  response = Net::HTTP.start(uri.hostname, uri.port, {}) do |http|
    http.request(request)
  end
  return JSON.parse(response.body)
# response.code
# response.body
end

# Query for LCCNS
def query_for_lccns(work)
  work_uri = "<" + work + ">"
 
  
  
  query="PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> SELECT DISTINCT ?isbn WHERE {" + work_uri + " bf:hasInstance ?instance1 .  ?instance1 bf:identifiedBy ?id1 . ?id1 rdf:type bf:Lccn . ?id1 rdf:value ?isbn . }"
  #puts query
  

  uri = URI.parse("http://localhost:3030/ds/sparql")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/json"
  request.set_form_data(
    "query" => query,
  )

  
  response = Net::HTTP.start(uri.hostname, uri.port, {}) do |http|
    http.request(request)
  end
  return JSON.parse(response.body)
# response.code
# response.body
end

def query_for_instances(work)
  work_uri = "<" + work + ">"
 
  
  
  query="PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> SELECT ?instance1 WHERE {" + work_uri + " bf:hasInstance ?instance1 .   }"
  #puts query
  

  uri = URI.parse("http://localhost:3030/ds/sparql")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/json"
  request.set_form_data(
    "query" => query,
  )

  
  response = Net::HTTP.start(uri.hostname, uri.port, {}) do |http|
    http.request(request)
  end
  return JSON.parse(response.body)
# response.code
# response.body
end

# Query relationships where work is an OBJECT of another object
def query_for_relationships(work)
  work_uri = "<" + work + ">"
 
  
  
  query="PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> SELECT ?subject ?predicate (GROUP_CONCAT(?type) AS ?types) WHERE { ?subject ?predicate " + work_uri + ". ?subject rdf:type ?type .    } GROUP BY ?subject ?predicate"
  #puts query
  

  uri = URI.parse("http://localhost:3030/ds/sparql")
  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/json"
  request.set_form_data(
    "query" => query,
  )

  
  response = Net::HTTP.start(uri.hostname, uri.port, {}) do |http|
    http.request(request)
  end
  return JSON.parse(response.body)
end

#query_for_isbns("https://svde.org/pcc/rdfBibframe/Work/544297-1")
get_isbns()