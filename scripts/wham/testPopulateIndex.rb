require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'dotenv/load'

require 'active_support/core_ext/hash'

#Load from JSON structured like {type:author, label: , rank: ..}
#Data files will be divided by type, so type can be an argument
#instead of being retrieved from the file
def load_json_label_values(entity_type, filename, unmatched_filename)
  file = File.read(filename)
  data = JSON.parse(file)
  update_info_for_labels(data, entity_type, unmatched_filename)
end


# Update info by looking up URI and getting additional info like variant labels
# label_data = array of objects with "label" as key and "rank" as key
# Packaging as 2000 documents as a time
def update_info_for_labels(label_data, entity_type, unmatched_filename)
  unmatched_labels = []
  # For documents currently in the solr_documents array, i.e. yet to be processed
  # save URI to index in the array in case we need to look any up during processing
  solr_documents_hash = {}
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
        #Also get pseudonyms
        pseudonyms = retrieve_pseudonyms(uri, entity_type)
        if(pseudonyms.length > 0)
          solr_data["pseudonym_data"] = pseudonyms      	
        end
        # Retrieve wikidata pseudonyms
        wikidata_info = retrieve_wikidata_info(uri, entity_type)      
        solr_data = solr_data.merge(wikidata_info)
        generated_doc = generate_solr_document(solr_data)
        
        # Questioning whether this adequately covers the situation where
        # the document hasn't been added yet so see also may be removed from display
        # but then would need to be RE-ADDED if encountered
          
        # Additional step for processing see also references in/between elements
        # puts "processing generated solr doc for any see also cross references"
   		# process_results = process_see_also_for_doc(generated_doc, solr_documents_hash)     
   		# solr_documents_hash = process_results["solr_documents_hash"]
   		# generated_doc = process_results["solr_doc"]
        solr_documents_hash[uri] = generated_doc
        solr_counter = solr_counter + 1
   		
    else
      unmatched_labels << info
    end   
    
    # As we iterate through labels, every 2000 solr documents, we write directly to the index
    if solr_counter == 2000
        puts counter
    	write_file(unmatched_labels, unmatched_filename)
  		update_suggest_index(solr_documents_hash.values)
  		# reset counter and arrays
  		solr_counter = 0
  		solr_documents_hash = {}
  		umatched_labels = []
    end
  }  
 #puts solr_documents.to_s
 # IF there are any left over values in solr_documentsm write them out now
  if (solr_documents_hash.values.length > 0)
    write_file(unmatched_labels, unmatched_filename) 
   
    # Write documents to Solr
    update_suggest_index(solr_documents_hash.values)
  end
  puts "last iteration, added this many solr documents"
  puts solr_documents_hash.values.length.to_s
 
  puts JSON.pretty_generate(solr_documents_hash.values)
  puts "last iteration, added this many to unmatched list"
  puts unmatched_labels.length.to_s

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
  	when "genre"
  	    uri = lookup_genre(label)
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
  
  if(entity_type == "subject" || entity_type == "location")
    query = generate_variant_query(uri)
    auth = "fast"
  end
  
  if(entity_type == "genre")
    query = generate_variant_query(uri)
    auth = "loc_genre"
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



## Lookup URIs for a given label may involve more than one method
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
  puts "lookup author browse index #{label}"
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
  query_lc_suggest("names", label)
end


#LCGFT
def lookup_genre(label)
  uri = nil 
  result = query_lcgft_suggest(label)
  uri = get_lcnaf_uri_from_suggest(result)
  # If input label doesn't provide result and it ends in period, try to strip period to see if match can be obtained
  # This is because there are causes where the author index has a period but LCNAF doesn't
  if uri.nil? && label.end_with?(".")
  	label = label.chop
  	result = query_lcgft_suggest(label)
  	if(!result.nil?)
  	  uri = get_lcnaf_uri_from_suggest(result)
  	end
  end
  uri
end

def query_lcgft_suggest(label)
  query_lc_suggest("genreForms", label)
end


def query_lc_suggest(authority, label)
  rdftype = (authority === "genreForms")? "&rdftype=GenreForm": (authority === "names")? "&rdftype=PersonalName" : ""
  result = nil
  lc_url = "http://id.loc.gov/authorities/" + authority + "/suggest/?q=" + URI.encode(label) + rdftype + "&count=1";
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
 puts fast_url.to_s
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
    if(URI.encode(result_label.unicode_normalize.downcase) === URI.encode(label.unicode_normalize.downcase))
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
  mapping = {"type" => "type_s","label" => "label_s","uri" => "uri_s","variants" => "variants_t", "rank" => "rank_i", "wd_uri" => "wd_uri_s", "wd_description" => "wd_description_s", "wd_pseudonyms" => "wd_pseudonyms_t"}
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
  
  #Additional processing for pseudonym data
  if(solr_data.key?("pseudonym_data"))
    pseudonyms = solr_data["pseudonym_data"]
  	solr_document["pseudonyms_ss"] = pseudonyms.map { |p| p.to_json }
    solr_document["pseudonyms_t"] = pseudonyms.map { |p| p["label"] }
    #also preserving copy of original see also info from loc
    solr_document["loc_pseudonyms_ss"] = solr_document["pseudonyms_ss"]
  end
  solr_document
end

def update_suggest_index(solr_documents)
   solr_url = ENV["SUGGEST_SOLR"]
   solr = RSolr.connect :url => solr_url
   solr.add solr_documents, :add_attributes => {:commitWithin => 10}
end

## Pseudonym retrieval

# Pseudonym retrieval  
def retrieve_pseudonyms(uri, entity_type)
  query = nil
  pseudonyms = []
  if(entity_type == "author")
    query = generate_pseudonym_query(uri)
    if !query.nil?
      auth = "loc_names"
      results = execute_query(auth, query)
      pseudonyms = results.map { |r| {"label" => r["label"]["value"], "uri" => r["uri"]["value"]} }
    end
  end
  return pseudonyms
end

# Uses LOC URI to get see also URIs and labels where they exist
def generate_pseudonym_query(uri)
  return "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " + 
  "SELECT ?uri ?label WHERE {" + 
  "<" + uri + "> <http://www.w3.org/2000/01/rdf-schema#seeAlso> ?uri ." + 
  "?uri <http://www.w3.org/2004/02/skos/core#prefLabel> ?label . " + 
  "FILTER NOT EXISTS {?uri <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.loc.gov/mads/rdf/v1#DeprecatedAuthority> .}" +
  "}"
end



## Wikidata 

#Although we have wikidata URIs for a lot of cases, no need to look at the index first because we want additional info here
# that we don't have
def retrieve_wikidata_info(loc_uri, entity_type)
  wd_info = {} 
  # Query will return wikidata URI where it exists as well as possible pseudonyms
  if(entity_type == "author")
    query = generate_wikidata_query(loc_uri)
    results = execute_wikidata_query(query)
    if(!results.nil? && results.key?("results") && results["results"].key?("bindings") && results["results"]["bindings"].length > 0)
      binding = results["results"]["bindings"][0]
      if binding.key?("entity") && binding["entity"].key?("value")
      	uri = binding["entity"]["value"]
      	wd_info = {"wd_uri" =>  uri}
      	if binding.key?("description") && binding["description"].key?("value")
      		description = binding["description"]["value"]
      		wd_info["wd_description"] = description
      	end 
      	if binding.key?("pseudonyms") && binding["pseudonyms"].key?("value")
      		pseudonyms = binding["pseudonyms"]["value"]
      		ps_array = pseudonyms.split("|")
      		wd_info["wd_pseudonyms"] = ps_array
      	end
      end 
    end
  end
  wd_info
end

def generate_wikidata_query(loc_uri)
  # Get local name from loc_uri
  local_name = loc_uri.split("/")[-1]
  return "SELECT ?entity ?entityLabel ?description (GROUP_CONCAT(?pseudonym;SEPARATOR=\"|\") AS ?pseudonyms) WHERE {?entity wdt:P244 \"" + local_name + "\" . OPTIONAL {?entity wdt:P742 ?pseudonym .} OPTIONAL {?entity schema:description ?description. FILTER(lang(?description) = 'en')} SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }} GROUP BY  ?entity ?entityLabel ?description"
end

def execute_wikidata_query(query) 
  wikidata = "https://query.wikidata.org/sparql?query=" + URI.encode(query);
  uri = URI.parse(wikidata)
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/sparql-results+json"
  request["User-Agent"] = "My Ruby Script"
  req_options = {
	use_ssl: uri.scheme == "https",
  }	
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  JSON.parse(response.body)
end


#### Queries to evaluate if see also URIs already exist within the index

# Pass in array of stringifed JSON that needs to be parsed


# query index to retrieve all documents that have any see also references

def retrieve_docs_with_see_also()
   solr_url = ENV["SUGGEST_SOLR"]
   solr = RSolr.connect :url => solr_url
   response = solr.get 'select', :params => {:q => 'pseudonyms_ss:*'}
   return response["response"]["docs"]
end

def update_see_also()
  # Read in mark twain original solr doc
  #json = File.read("testsolr_doc.json")
  #obj = JSON.parse(json)
  
  update_docs = []
  see_also_docs = retrieve_docs_with_see_also()
  see_also_docs.each{|doc|
    updates = get_see_also_info(doc)
    updates.each{|update|
      # consider using map
      update_docs << {"id":update["id"], "pseudonyms_ss":{"set": update["pseudonyms_ss"]}, "pseudonyms_t":{"set":update["pseudonyms_t"]} }
    }
  }
   
  puts "final update results"
  puts JSON.pretty_generate(update_docs)
  update_suggest_index(update_docs)
  # Update Solr
end

# Argument = solr document being processed
# if called from within process of generating documents, also
# has hash used to save documents so far
def get_see_also_info(solr_doc)
  update_docs = []
  uri = solr_doc["uri_s"]
  label = solr_doc["label_s"]
  puts "Get See Also Info for Solr document #{uri} and #{label}"
  #see also = array of stringified JSON objects
  # Using dup b/c we update the solr document itself and it seems
  # like the reference to the field in the document changes if the doc is changed
  see_also_values = solr_doc["pseudonyms_ss"].dup
  puts "see also values for #{label} are"
  puts JSON.pretty_generate(see_also_values)
 
  see_also_values.each{|see_also|
    see_json = JSON.parse(see_also)
    see_uri = see_json["uri"]
    see_label = see_json["label"]
    # Test to see if this URI already exists within Solr
    uri_docs = query_uri_exists(see_uri)
    
    see_also_exists = (uri_docs.length > 0) ? true: false
    puts "#{see_uri} has corresponding solr doc? #{see_also_exists.to_s}"
    solr_doc = update_with_see_also(solr_doc, see_json, see_also_exists)
  }
  update_docs << solr_doc
  return update_docs
end

# update solr document in the case where a solr doc exists for see_also URI
def update_with_see_also(solr_doc, see_json, see_doc_exists)
	if(see_doc_exists == true)
		# Remove text from pseudonym_t
		see_label = see_json["label"]
		# This should return an array of text values
		puts "update with see also solr doc input"
		puts solr_doc.keys.to_s
		if(solr_doc.key?("pseudonyms_t"))
		  pseudonym_text = solr_doc["pseudonyms_t"]
		  pseudonym_text.delete_if {|t| t == see_label}
		  solr_doc["pseudonyms_t"] = pseudonym_text
		end  
	else
		# Remove see also URIs from display field
		see_uri = see_json["uri"]
		if(solr_doc.key?("pseudonyms_ss"))
		  pseudonym_ss = solr_doc["pseudonyms_ss"]
		  pseudonym_ss.delete_if {|ss|
		    ss_json = JSON.parse(ss)
		    if (ss_json["uri"] == see_uri)
		  	  true
		    else
		      false
		    end
		  }
		  solr_doc["pseudonyms_ss"] = pseudonym_ss
		end
	end
	return solr_doc
end


# Given an LOC URI, does this URI exist already in the index
# IF uri exists, returns response
def query_uri_exists(uri)
   solr_url = ENV["SUGGEST_SOLR"]
   solr = RSolr.connect :url => solr_url
   response = solr.get 'select', :params => {:q => 'uri_s:' + uri}
   return response["response"]["docs"]
   
end

#If set of documents has a see also reference to a URI
def has_docs_reference(docs, uri)
  len = docs.length
  docs.each{|doc| 
    has_ref = has_doc_reference(doc, uri)
    if has_ref == true 
    	return true
    end
  }
  
  return false
end

def has_doc_reference(doc, uri)
    puts "Checking for reference in this doc"
    puts doc["uri_s"] 
  	if doc.key?("pseudonyms_ss")
  		ss = doc["pseudonyms_ss"]
        ss.each{|ss_i|
          ss_j = JSON.parse(ss_i)
          ss_uri = ss_j["uri"]
          # If see also doc refers to the URI being passed
          if(ss_uri === uri)
          	return true
          end
        }
  	end
  	return false 
end

def does_doc_exist(docs)
	return docs.length > 0
end
 
## Add pseudonyms for solr documents that already exist
def add_pseudonym_info()
  # Updates: to be written at 100 Solr documents at a time
  # The first query should result in a list of all the URIs with type author contained within the index
  all_docs = retrieve_URIs_in_index("author")
  puts all_docs.to_s
  all_docs.each{|doc|
    id = doc["id"]
    uri = doc["uri_s"] 
    solr_data = {"id":id, "uri":uri}.with_indifferent_access
    #Also get pseudonyms
    pseudonyms = retrieve_pseudonyms(uri, "author")
    if(pseudonyms.length > 0)
      solr_data["pseudonym_data"] = pseudonyms      	
    end
    # Retrieve wikidata pseudonyms
    wikidata_info = retrieve_wikidata_info(uri, "author")      
    solr_data = solr_data.merge(wikidata_info)
    generated_doc = generate_solr_document(solr_data)
    puts "resulting solr document"
    puts JSON.pretty_generate(generated_doc)
    
  }
  
end

def retrieve_URIs_in_index(entity_type)
  solr_url = ENV["SUGGEST_SOLR"]
  solr = RSolr.connect :url => solr_url
  response = solr.get 'select', :params => {:q => 'type_s:' + entity_type, :rows => 400000, :fl => 'id,uri_s'}
  return response["response"]["docs"]
end

# Arguments: solr doc in the process of being generated, URI to doc hash, and solr documents array
# for this batch
def process_see_also_for_doc(generated_doc, solr_documents_hash)
  get_see_also_info(generated_doc, solr_documents_hash)
end


## Argument processing, file reading and writing methods
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
  
  # If updating see also info, need only 
  if(action_type == "update")
  	update_see_also()
  end
  
  if(action_type == "unmatched")
    #query_unmatched(unmatched_filename)
  end
  
  if(action_type == "pseudonym")
  	add_pseudonym_info()
  end
end

### Running the file with these arguments will kick off the processing method 

action_type = ARGV[0] 
entity_type = ARGV[1] || ""
filename = ARGV[2] || ""
unmatched_filename = ARGV[3] || ""

process_file(action_type, entity_type, filename, unmatched_filename)