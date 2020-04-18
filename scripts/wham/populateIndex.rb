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
# Packaging as 2000 documents as a time
def update_info_for_labels(label_data, entity_type, unmatched_filename)
  unmatched_labels = []
  solr_documents = []
  counter = 0
  solr_counter = 0
  label_data.each { |info| 
    counter = counter + 1 
    solr_data = {}
    label = info["label"]
    uri = retrieve_uri_for_label(label, entity_type)
    if(! uri.nil?)
        solr_data["uri"] = uri
        solr_data["type"] = entity_type
        solr_data = solr_data.merge(info)
        labels = retrieve_variant_labels(uri, entity_type)
        if(labels.length > 0)
          solr_data["variants"] = labels
        end
        solr_documents << generate_solr_document(solr_data)
        solr_counter = solr_counter + 1
    else
      unmatched_labels << info
    end   
    
    # As we iterate through labels, every 2000 solr documents, we write directly to the index
    if solr_counter == 2000
        puts counter
    	write_file(unmatched_labels, unmatched_filename)
  		update_suggest_index(solr_documents)
  		# reset counter and arrays
  		solr_counter = 0
  		solr_documents = []
  		umatched_labels = []
    end
  } 
 
 # IF there are any left over values in solr_documentsm write them out now
  if (solr_documents.length > 0)
    write_file(unmatched_labels, unmatched_filename) 
   
    # Write documents to Solr
    update_suggest_index(solr_documents)
  end
 #This will be replaced once we handle real data, this is to keep track of solr documents being created
    #write_file(solr_documents, "solrdocs.json") 
end

def retrieve_uri_for_label(label, entity_type)
  uri = nil
  case entity_type
  	when "author"
  		uri = lookup_author(label) 
  	when "subject"
  		uri = lookup_fast(label)
  	when "location"
  		uri = lookup_fast(label)
  	else
  end
  return uri
end

def retrieve_variant_labels(uri, entity_type)
  query = nil
  labels = []
  if(entity_type == "author")
    query = generate_variant_query(uri)
    auth = "loc_names"
  end
  
  if(entity_type == "subject")
    query = generate_variant_query(uri)
    auth = "fast"
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
def generate_variant_query(uri)
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
  	if(!result.nil?)
  	  uri = get_lcnaf_uri_from_suggest(result)
  	end
  end
  uri
end

def query_lcnaf_suggest(label)
  result = nil
  lc_url = "http://id.loc.gov/authorities/names/suggest/?q=" + URI.encode(label) + "&rdftype=PersonalName" + "&count=1";
  begin
    url = URI.parse(lc_url)
    resp = Net::HTTP.get_response(url)
    data = resp.body
    result = JSON.parse(data)
  rescue JSON::ParserError => e
  	puts "Rescued: #{e.inspect}"
  	puts result.to_s
    puts label
  	puts lc_url
  	result = nil
  rescue StandardError => e
    puts "Rescued: #{e.inspect}"
    puts result.to_s
    puts label
  	puts lc_url
  	result = nil
  end
  result
end

def get_lcnaf_uri_from_suggest(result)
  # sample result ["einstein",["Einstein (Musician)"],["1 result"],["http://id.loc.gov/authorities/names/no2002102271"]]
  # Need to ensure query and label are equivalent
  # 0 = query, 1 = label, 2 = number of results, 3 = uri
  (!result.nil? && result[1].length > 0 && result[3].length > 0 && result[0] === result[1][0]) ? result[3][0] : nil
end

# Subjects and Locations - query FAST
def lookup_fast(label)
	uri = nil
	# OCLC's own suggest doesn't seem to prioritize exact match to string
	# instead seems to be using usage
	# Need to transform subdivision > to -- for FAST
	label = label.gsub(" > ", "--")
	result = query_fast_suggest(label)  
	uri = get_uri_from_fast_result(label, result)
	
	#result = query_fast_cache(label)
	#uri = get_qa_result_uri(label, result)
	
end

# For subject
def query_fast_suggest(label)
 topicFacet = "suggest50";
 #fast_url = "http://fast.oclc.org/searchfast/fastsuggest?query=" + label + "&fl=" + topicFacet + ",id&queryIndex=" + topicFacet + "&queryReturn=id,*&rows=10&wt=json&suggest=fastSuggest";
 #Bad URI issue
 fast_url = "http://fast.oclc.org/fastIndex/select?q=altphrase:" + URI.encode("\"" + label + "\"") + "&rows=1&start=0&version=2.2&indent=on&fl=id,fullphrase,type&sort=usage desc&wt=json"
 url = URI.parse(fast_url)
 resp = Net::HTTP.get_response(url) 
 data = resp.body
 result = JSON.parse(data) 
end

## Querying cache and looking for exact label matches
def query_fast_cache(label)
 # Not sure why maxRecords = 1 is taking longer
 qa_url = "https://lookup.ld4l.org/authorities/search/linked_data/oclcfast_ld4l_cache/concept?q=" + label + "&maxRecords=4"
 url = URI.parse(qa_url)
 resp = Net::HTTP.get_response(url) 
 data = resp.body
 result = JSON.parse(data) 
end

def get_qa_result_uri(label, result)
  uri = nil
  # Checking if label is exactly the same
  if result.length > 0
    result_label = result[0]["label"]
    uri = (result_label === label)? result[0]["uri"]: nil
  end
  uri
end

def get_uri_from_fast_result(label, result)
  uri = nil
  if (result.key?("response") && result["response"].key?("docs") && result["response"]["docs"].length > 0)
    result_label = result["response"]["docs"][0]["fullphrase"]
    # Check if labels equivalent
    if(result_label.downcase === label.downcase)
	  	id = result["response"]["docs"][0]["id"]
	  	#remove fst at beginning of id
	  	#remove leading zeros
	  	id = id[3..-1]
	  	id.sub!(/^0+/, "")
	  	uri = "http://id.worldcat.org/fast/" + id
  	end
  end
  uri
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