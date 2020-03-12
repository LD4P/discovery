require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'time'

def parseDate(dateStr)
	begin
	    if(!dateStr.start_with?("t"))
  			date = Date.parse(dateStr)
  			return date
		else
			puts "unsure about this date so not using " + dateStr
			return nil
  		end
  	rescue StandardError => e
  		puts "error occurred with " + dateStr
  		puts "Rescued: #{e.inspect}"
  		return nil
  	end
end

#Changing this to enable using multiple files for this processing
def readFile(filename)
	#Save this environment variable, currently using a dummy variable, will need to change this with the URL intended
	solr_url = "http://example.org/solr/collection_name"
	
	file = File.read(filename)
	puts "After reading in wikidata file"
	data_hash = JSON.parse(file)
	puts "Ater parsing"
	results = data_hash["results"]["bindings"]
	solr_documents = []
	counter = 0
	solrcounter = 0
	results.each do |binding| 
	  counter = counter + 1
	  solrcounter = solrcounter + 1
	  #puts counter.to_s + " of " + results.length.to_s
	  #binding = results[0]
	  wikidataURI = binding["s"]["value"]
	  #puts wikidataURI
	  locName = binding["loc"]["value"]
	  if locName.start_with?("n")
	  	type = "name"
	  	locURI = "http://id.loc.gov/authorities/names/" + locName
	  elsif locName.start_with?("sh")
	  	type = "subject"
	  	locURI = "http://id.loc.gov/authorities/subjects/" + locName
	  else
	  	type = "other"
	  	locURI = locName
	  end
	  #puts type + "=" + locURI
	  locId = locURI.gsub("/","_")
	  #Generate beginning of solr document
	  solr_doc = {"id":locId,"loc_uri_s":locURI,"wd_uri_s":{"set":wikidataURI}, "type_s":type}
	  if binding.key?("birth") && binding["birth"].key?("value")
	    wd_birth = binding["birth"]["value"]
	  	solr_doc["wd_birth_s"] = {"set":wd_birth}
	  	birthDate = parseDate(wd_birth)
	  	if !birthDate.nil?
	  		solr_doc["wd_birthy_i"] = {"set":birthDate.year}
	  	end
	  end
	  
	  if binding.key?("death") && binding["death"].key?("value")
	    wd_death = binding["death"]["value"]
	  	solr_doc["wd_death_s"] = {"set":wd_death}
	  	deathDate = parseDate(wd_death)
	  	if !deathDate.nil?
	  		solr_doc["wd_deathy_i"] = {"set":deathDate.year}
	  	end
	  end
	  
	  #Also add image
	  if binding.key?("image") && binding["image"].key?("value")
	  	solr_doc["wd_image_s"] = {"set":binding["image"]["value"]}
	  end
	  
	  #Add start and end dates for activity if present
	  if binding.key?("start") && binding["start"]["value"]
	  	wd_start = binding["start"]["value"]
	  	solr_doc["wd_start_s"] = {"set":wd_start}
	  	startDate = parseDate(wd_start)
	  	if !startDate.nil?
	  		solr_doc["wd_starty_i"] = {"set":startDate.year}
	  	end
	  	
	  end
	  
	  if binding.key?("end") && binding["end"]["value"]
	  	wd_end = binding["end"]["value"]
	  	solr_doc["wd_end_s"] = {"set":wd_end}
	  	endDate = parseDate(wd_end)
	  	if !endDate.nil?
	  		solr_doc["wd_endy_i"] = {"set":endDate.year}
	  	end
	  end
	  
	  ##Collection solr documents and push every 20000
	  solr_documents.push(solr_doc)
	  if solrcounter == 20000
	  	puts "adding 20000 , " + counter.to_s + " of " + results.length.to_s
	    solr = RSolr.connect :url => solr_url
	    solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	    # Close connection
	    # solr.connection.close
	    # Reset counter and array
	  	solrcounter = 0
	  	solr_documents = []	  	
	  end
	  
	  #puts "adding Solr DOC"
	  #solr.add solr_doc, :add_attributes => {:commitWithin => 10}
	end
	#if any solr documents left over go ahead and add those
	if solr_documents.length
		puts "adding left over " + solr_documents.length.to_s
		solr = RSolr.connect :url => solr_url
		solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	end
	puts "done with processing " + filename
end


# Uncomment the blocks below to get the separate data
# i.e. birth dates from wikidata, death dates, start activity dates, end activity dates 
#solr.add solr_documents, :add_attributes => {:commitWithin => 10}
#puts "-------------->processing WD Birth"
#readFile("wdbirth.json")

#puts "-------------->processing WD Death"
#readFile("wddeath.json")

#puts "-------------->processing WD Start"
#readFile("wdstart.json")

#puts "-------------->processing WD End"
#readFile("wdend.json")

#puts "-------------->processing WD image"
#readFile("wdimage.json")
