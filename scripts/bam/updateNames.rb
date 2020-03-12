require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'time'
require 'edtf'

 
#do updates
def doUpdate()
    #make an environment variable or parameter, currently example value
    solr_url = "http://example.org/solr/collection_name"
    
    wikidataFile = "uauthors.json"
    #locFile = "locrwo.json"
    #wikidataFile = "uritest.json"
    #locFile = "lctest.json"
    
    puts "beginning read processing " 
    
	wfile = File.read(wikidataFile)
	wdata_hash = JSON.parse(wfile)
	
	puts "Parsed and read URIS file"
	puts Time.now.utc.iso8601
	#locHash = processLoc(locFile)
	puts "Before iterating through URIs"
	# Go through wikidata entities and update with LOC names, rwos where possible
	results = wdata_hash["response"]["docs"]
	solr_documents = []
	counter = 0
	solrcounter = 0
	results.each do |doc| 
	 
	  locUri = doc["loc_uri_s"]
	  binding = queryLOC(locUri)
	  
	  #Type of URI
	  locName = locUri.split("/")[-1]
	  #puts locName
	  if locName.start_with?("n")
	  	type = "name"
	  elsif locName.start_with?("sh")
	  	type = "subject"
	  else
	  	type = "other"
	  end
	  
	  if !binding.nil?
	     counter = counter + 1
	  	 solrcounter = solrcounter + 1	
	  
	  	 #binding = locHash[locUri]
	  	 #auth = binding["auth"]["value"]
	  	 authLabel = binding["authLabel"]["value"]
	  	 rwo = binding["rwo"]["value"]
	  	 
	  	 locId = locUri.gsub("/","_")
	  	 solr_doc = {"id":locId,"loc_uri_s":locUri,"rwo_uri_s":{"set":rwo}, "type_s":type, "authlabel_s":{"set":authLabel}}
	  	  
	  	  ##Collection solr documents and push every 20000
		  solr_documents.push(solr_doc)
		  #puts solr_documents.to_s
		  if solrcounter == 20000
		    puts "adding 20000 , " + counter.to_s + " of " + results.length.to_s
		    puts Time.now.utc.iso8601
		    solr = RSolr.connect :url => solr_url
		    solr.add solr_documents, :add_attributes => {:commitWithin => 10}
		  	solrcounter = 0
		  	solr_documents = []	  	
		  end	  	 
	  end  
	end
	#if any solr documents left over go ahead and add those
	if solr_documents.length
		puts "adding left over " + solr_documents.length.to_s
                puts Time.now.utc.iso8601
		solr = RSolr.connect :url => solr_url
		solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	end
	
end

def processLoc(locFile)
    puts "Read in LOC file"
	file = File.read(locFile)
	puts "Beginning parse"
	data_hash = JSON.parse(file)
	puts "LOC file parsed"
	results = data_hash["results"]["bindings"]
	resultsHash =  results.map { |result| [result["auth"]["value"], result] }.to_h
	puts "Mapping complete"
	return resultsHash
end

#Return the authorized name and RWO for this URI
def queryLOC(auth)
        # Use SPARQL query endpoint for your data, here replacing with example, used Dave's backup, thanks Dave!
   	uri = URI.parse("http://sparqlendpoint/sparql")
	request = Net::HTTP::Post.new(uri)
	request.body = "query=PREFIX madsrdf: <http://www.loc.gov/mads/rdf/v1#> SELECT ?authLabel ?rwo  WHERE {  <" + auth + "> madsrdf:authoritativeLabel ?authLabel . <" + auth + "> madsrdf:identifiesRWO ?rwo .}"
	#puts request.body.to_s
	req_options = {
	  use_ssl: uri.scheme == "https",
	}
	
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
	  http.request(request)
	end
	
	#response = Net::HTTP.get(uri.hostname, uri.port)
   	  
   	#puts response.body.to_s
	data_hash = JSON.parse(response.body)
	results = data_hash["results"]["bindings"]
	# Get the first
	
	if results.length
		r = results[0]
		#authLabel = r["authLabel"]["value"]
		#rwo = r["rwo"]["value"]
		return r
	end 
	
	return nil
	
	
end

doUpdate()
