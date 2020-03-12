require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
#Save this environment variable, here we're using an example Solr url that isn't real
solr_url = "http://example.org/solr"
#Also save this in environment variable
file = File.read('fulltree.json')

data_hash = JSON.parse(file)
results = data_hash["results"]["bindings"]
solr_documents = []
counter = 0
solrcounter = 0
results.each do |binding| 
  counter = counter + 1
  solrcounter = solrcounter + 1
  uri = binding["uri"]["value"]
  uriLabel = binding["uriLabel"]["value"]
  classification_value = binding["c"]["value"]
  classificationrange = []
  classificationFacet = {}
  puts uri + "-" + uriLabel + "-" + classification_value
  cArray = []
  # Multiple classifications?
  if(classification_value.include? "|")
	  cArray = classification_value.split("|")
  else
  	 cArray.push(classification_value)
  end
  
  cArray.each do |classification|
  	if(classification.include? "-")
	  	classificationrange = classification.split("-")
	        r1 = classificationrange[0]
	        r2 = classificationrange[1]
	        classificationFacet[r1[0..0]] = "true"
	        classificationFacet[r1[0..1]] ="true"
	        if(r1[0..0] != r2[0..0])
	         classificationFacet[r2[0..0]]="true"
	        end
	        if(r1[0..1] != r2[0..1])
	         classificationFacet[r2[0..1]] = "true"
	        end
	  
	  else
	    classificationFacet[classification[0..0]]= "true"
	    classificationFacet[classification[0..1]] = "true"
	  end
  end
 
  id = uri.gsub("/","_")
  solr_documents.push({"id":id,"uri_s":uri,"label_s":uriLabel,"classification_ss":cArray,"classification_facet":classificationFacet.keys})
end
puts "Solr documents look like"
puts solr_documents.to_s

solr = RSolr.connect :url => solr_url
#response = solr.get 'select', :params => {:q => '*:*'}

solr.add solr_documents, :add_attributes => {:commitWithin => 10}
