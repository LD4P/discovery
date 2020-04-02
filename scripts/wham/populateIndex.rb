require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'dotenv/load'


# Load file (this expects the raw results from Solr with the facet values and counts)
def load_label_values(filename)	
  # This process will have to change with a large file
  file = File.read(filename)
	data_hash = JSON.parse(file)
  authors = data_hash["facet_counts"]["facet_fields"]["author_facet"]
  labels = authors.select.with_index { |_, i| i.even? }
  counts = authors.select.with_index { |_, i| i.odd? }
  update_info_for_labels(labels, "agent")
end

# Update info by looking up URI and getting additional info like variant labels
# label_data = array of labels
def update_info_for_labels(label_data, entity_type)
  label_data.each { |label| 
    uri = retrieve_uri_for_label(label, entity_type)
    if(! uri.nil?)
        labels = retrieve_variant_labels(uri, entity_type)
    end
    puts label
    puts "Variants: " + labels.to_s
  }
end

def retrieve_uri_for_label(label, entity_type)
  uri = nil
  if(entity_type == "agent") 
    uri = lookup_author_browse_index(label)
  end
  return uri
end

def retrieve_variant_labels(uri, entity_type)
  query = nil
  labels = []
  if(entity_type == "agent")
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

def generate_agent_query(uri)
  return "SELECT ?label WHERE {  <" + uri + "> <http://www.w3.org/2008/05/skos-xl#altLabel> ?label .  FILTER (isLiteral(?label))}"
end

## Lookupg URIs for a given label may involve more than one method
def lookup_author_browse_index(label)
  solr_url = ENV["AUTHOR_BROWSE_INDEX"] + "/select?q=authlabel_s:\"" + label + "\"&wt=json";
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

#test_uri = "http://id.loc.gov/authorities/names/n79021164"
test_label_data = ["Twain, Mark, 1835-1910"]
#retrieve_variant_labels(test_uri, "agent") 
#lookup_author_browse_index(test_label)
update_info_for_labels(test_label_data, "agent")