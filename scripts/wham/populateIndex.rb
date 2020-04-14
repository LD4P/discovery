require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'dotenv/load'



#Load from JSON structured like {type:author, label: , rank: ..}
#Data files will be divided by type, so type can be an argument
#instead of being retrieved from the file
def load_json_label_values(entity_type, filename, unmatched_filename)
  file = File.read(filename)
  data = JSON.parse(file)
  update_info_for_labels(data, entity_type, unmatched_filename)
end

# Load file (this expects the raw results from Solr with the facet values and counts)
def load_label_values(filename)	
  # This process will have to change with a large file
  file = File.read(filename)
	data_hash = JSON.parse(file)
  authors = data_hash["facet_counts"]["facet_fields"]["author_facet"]
  labels = authors.select.with_index { |_, i| i.even? }
  counts = authors.select.with_index { |_, i| i.odd? }
  # Need to transform this into array of objects with "label" and "rank"
  #update_info_for_labels(labels, "author")
end

# Update info by looking up URI and getting additional info like variant labels
# label_data = array of objects with "label" as key and "rank" as key
def update_info_for_labels(label_data, entity_type, unmatched_filename)
  unmatched_labels = []
  solr_documents = []
  label_data.each { |info| 
    solr_data = {}
    label = info["label"]
    uri = retrieve_uri_for_label(label, entity_type)
    if(! uri.nil?)
        solr_data["uri"] = uri
        solr_data = solr_data.merge(info)
        labels = retrieve_variant_labels(uri, entity_type)
        if(labels.length > 0)
          solr_data["variants"] = labels
        end
        solr_documents << generate_solr_document(solr_data)
    else
      unmatched_labels << label
    end    
  } 
  
  puts solr_documents.to_s
  puts unmatched_labels.to_s
  #write_file(unmatched_labels, unmatched_filename)
  
  #This will be replaced once we handle real data, this is to keep track of solr documents being created
  #write_file(solr_documents, "solrdocs.json")
  
  # Write documents to Solr
  #update_suggest_index(solr_documents)
end

def retrieve_uri_for_label(label, entity_type)
  uri = nil
  case entity_type
  	when "author"
  		uri = lookup_author(label) 
  	when "subject"
  		uri = lookup_fast(label)
  	else
  end
  return uri
end

def retrieve_variant_labels(uri, entity_type)
  query = nil
  labels = []
  if(entity_type == "author")
    query = generate_agent_query(uri)
    auth = "loc_names"
  end
  
  if !query.nil?
    results = execute_query(auth, query)
    labels = results.map { |r| r["label"]["value"]}
  end
  return labels
end

def execute_query(auth, query) 
  endpoint = ENV["ENDPOINT"]
  uri = URI.parse(endpoint.to_s + auth + "/sparql")
  request = Net::HTTP::Post.new(uri)
  request.body = "query=" + query
  req_options = {
	use_ssl: uri.scheme == "https",
  }	
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
 
  data_hash = JSON.parse(response.body)
  results = data_hash["results"]["bindings"]
  return results
end

# SPARQL queries
#Variant label query
def generate_agent_query(uri)
  return "SELECT ?label WHERE {  <" + uri + "> <http://www.w3.org/2004/02/skos/core#altLabel> ?label .}"
end

# Possibilities for separately obtaining Wikidata URIs for an LOC along with description 
# See Also relationships will need to be pruned to remove any deprecated authorities

# Looking up Wikidata


# Looking up id.loc.gov suggest for any headings (name or subject etc.) that do not appear within the author index



## Lookupg URIs for a given label may involve more than one method
def lookup_author(label)
	uri = nil
	uri = lookup_author_browse_index(label)
	# If no URI above, do a query against id.loc.gov
	if uri.nil?
		uri = lookup_lcnaf(label)
	end
	# If there is a period at the end and no results come back
	# Query without an ending period
	uri
end

# Lookup author browse index
def lookup_author_browse_index(label)
  solr_url = ENV["AUTHOR_BROWSE_INDEX"] + "/select?q=authlabel_s:\"" + URI.encode(label) + "\"&wt=json";  
  url = URI.parse(solr_url)
  resp = Net::HTTP.get_response(url)
  data = resp.body
  result = JSON.parse(data)
  if(!result.nil? && result.key?("response")  && result["response"].key?("docs") && result["response"]["docs"].length > 0)
    # Relying on first hit, there should only be one
    doc = result["response"]["docs"][0]
    # To do: check this key exists
    return doc["loc_uri_s"]
  end
  return nil
end

# lookup lcnaf suggest
# It may be better to simply strip the period before checking to prevent a second call when one would suffice
# That said, we need to confirm there aren't cases where somehow the ending period alone distinguishes between entries?
def lookup_lcnaf(label)
  uri = nil 
  result = query_lcnaf_suggest(label)
  uri = get_lcnaf_uri_from_suggest(result)
  # If input label doesn't provide result and it ends in period, try to strip period to see if match can be obtained
  # This is because there are causes where the author index has a period but LCNAF doesn't
  if uri.nil? && label.end_with?(".")
  	label = label.chop
  	result = query_lcnaf_suggest(label)
  	uri = get_lcnaf_uri_from_suggest(result)
  end
  puts result.to_s
  uri
end

def query_lcnaf_suggest(label)
  lc_url = "http://id.loc.gov/authorities/names/suggest/?q=" + label + "&rdftype=PersonalName" + "&count=1";
  url = URI.parse(lc_url)
  resp = Net::HTTP.get_response(url)
  data = resp.body
  result = JSON.parse(data)
  return result
end

def get_lcnaf_uri_from_suggest(result)
  # sample result ["einstein",["Einstein (Musician)"],["1 result"],["http://id.loc.gov/authorities/names/no2002102271"]]
  # Need to ensure query and label are equivalent
  # 0 = query, 1 = label, 2 = number of results, 3 = uri
  result[1].length > 0 && result[3].length > 0 && result[0] === result[1][0] ? result[3][0] : nil
end

# Subjects and Locations - query FAST
def lookup_fast(label)
	uri = nil
	result = query_fast(label)
	uri = get_uri_from_fast_result(result)
	
end

def query_fast(label)
 topicFacet = "suggest50";
 label = "biology"
 fast_url = "http://fast.oclc.org/searchfast/fastsuggest?query=" + label + "&fl=" + topicFacet + "&queryReturn=id,*&rows=10&wt=json";
 url = URI.parse(fast_url)
 resp = Net::HTTP.get_response(url) 
 data = resp.body
 result = JSON.parse(data) 
end

def get_uri_from_fast_result(result)
  uri = nil
  if (result.key?("response") && result["response"].key?("docs") && result["response"]["docs"].length > 0)
    puts result.to_s
  	id = result["response"]["docs"][0]["id"]
  	puts id
  	#remove fst at beginning of id
  	puts id[3..-1]
  	uri = "http://id.worldcat.org/fast/" + id[3..-1]
  end
  puts result.to_s
  uri
  #result.key?("response") 
end
 
# Write unmatched labels to a file for later processing
def write_file(json_data, filename)
  File.open(filename,"w") do |f|
    f.write(JSON.pretty_generate(json_data))
  end
end
#test_uri = "http://id.loc.gov/authorities/names/n79021164"
#test_label_data = ["Twain, Mark, 1835-1910"]
#retrieve_variant_labels(test_uri, "author") 
#lookup_author_browse_index(test_label)
#update_info_for_labels(test_label_data, "author")

# Method to start process of getting labels
def process_file(action_type, entity_type, filename, unmatched_filename)
  if(action_type == "load")
    load_json_label_values(entity_type, filename, unmatched_filename)
  end
  
  if(action_type == "unmatched")
    #query_unmatched(unmatched_filename)
  end
end


## Solr document generation
# solr_data is an object with all the necessary fields and values for adding an entirey new Solr document
# or one with certain if updating a document
# In both cases, an id field is required
def generate_solr_document(solr_data)
  # Hash for solr document
  solr_document = {}
  # Generate id
  id = solr_data["uri"].gsub("/","_") 
  solr_document["id"] = id
  # Base mapping from json field to solr doc field
  mapping = {"type" => "type_s","label" => "label_s","uri" => "uri_s","variants" => "variants_t", "rank" => "rank_i"}
  mapping.keys.each do |key| 
    # If the key is present in the input data, map appropriately
    if solr_data.key?(key)
      solr_document[mapping[key]] = solr_data[key]
    end
  end
  # label_s should also be copied to label_t in an array
  if(solr_document.key?("label_s"))
    solr_document["label_t"] = [] << solr_document["label_s"]
  end
  solr_document
end

def update_suggest_index(solr_documents)
   solr_url = ENV["SUGGEST_SOLR"]
   solr = RSolr.connect :url => solr_url
   solr.add solr_documents, :add_attributes => {:commitWithin => 10}
end

### Running the file with these arguments will kick off the processing method 

action_type = ARGV[0]
entity_type = ARGV[1]
filename = ARGV[2]
unmatched_filename = ARGV[3]


process_file(action_type, entity_type, filename, unmatched_filename)