require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'csv'

def readFile(filename)
	#Save this environment variable
	solr_url = "http://example.org/subject_collection"
 	solr_documents = []
	counter = 0
	solrcounter = 0
	CSV.foreach(filename,  col_sep: "\t" , headers: true) do |row|
    counter = counter + 1
	  solrcounter = solrcounter + 1
		uri = row['?uri'].delete_prefix('<').delete_suffix('>')
		label = row['?label']
    id = uri.gsub("/","_")
    solr_doc = {"id":id,"uri_s":uri,"label_s":label, "label_t": label}
    solr_documents.push(solr_doc)
	  if solrcounter == 20000
	  	puts "adding 20000 , " + counter.to_s 
	    solr = RSolr.connect :url => solr_url
	    solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	  	solrcounter = 0
	  	solr_documents = []	  	
	  end
	end # end of CSV loop
   if solr_documents.length
  		puts "adding left over " + solr_documents.length.to_s
  		solr = RSolr.connect :url => solr_url
  		solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	 end
end

readFile("lcsh.tsv")
