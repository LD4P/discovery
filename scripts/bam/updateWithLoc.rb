require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'rsolr'
require 'time'
require 'edtf'

 
def getYear(dateStr)
 	begin
 		  ## If EDTF year, then additional parsing may be required	  
 		    returnYear = nil
 		    if !dateStr.nil?	  
  	    		dateStr_s = dateStr.sub("(edtf)", "")
  	    		dateStr_s = dateStr_s.strip
  	    		# E.g. format 20150101 will not return with edtf but will with regular date parse
  	    		returnDate = Date.edtf(dateStr_s) || Date.parse(dateStr_s)
  	    		if  !returnDate.nil? 
  	    			returnYear = parseYear(returnDate)
  	    		end
  	    	end
	  	    return returnYear	
	  	rescue StandardError => e
	  		puts "Get YEAR - error occurred with -" + dateStr + "-"
	  		puts dateStr.class
	  		puts "Rescued: #{e.inspect}"
	  	    begin
	  	    	return Date.parse(dateStr).year
	  	    rescue
	  	    	puts "Second RESCUE: nil for " + dateStr
	  	    	return nil
	  	    end
	  	end
end

def parseYear(dateEDF)
	if dateEDF.instance_of? EDTF::Set
		datesA = dateEDF.to_a
		#puts "Set date" + dateEDF.to_s
		# Return first element if it exists
		if datesA.length && !datesA[0].nil?
			return datesA[0].year
		end
		return nil
	elsif dateEDF.instance_of? EDTF::Interval
		puts "Interval date " + dateEDF.to_s
		return nil
	elsif dateEDF.instance_of? EDTF::Epoch
		puts "Epoch date " + dateEDF.to_s
		return nil
	elsif dateEDF.instance_of? EDTF::Season
		puts "Season date " + dateEDF.to_s
		return nil
	else
		return dateEDF.year
	end
end
#Save this environment variable

#file name for either birth or death, and file type = birth or death
def readProcessFile(filename)
    # use environment variable or argument, here using example Solr url which is not real
    #solr_url = "http://example.org/solr/collection_name"
    solr = RSolr.connect :url => solr_url
    
    puts "beginning read processing " + filename
	file = File.read(filename)
	data_hash = JSON.parse(file)
	results = data_hash["results"]["bindings"]
	solr_documents = []
	counter = 0
	solrcounter = 0
	results.each do |binding| 
	  counter = counter + 1
	  solrcounter = solrcounter + 1	
	  #binding = results[0]
	  auth = binding["auth"]["value"]
	  authLabel = binding["authLabel"]["value"]
	  rwo = binding["rwo"]["value"]
	 
	  locId = auth.gsub("/","_")
	  #Set up solr document, this may be overriding an existing document
	  solr_doc = {"id":locId,"loc_uri_s":auth,"rwo_uri_s":{"set":rwo}, "type_s":"name", "authlabel_s":{"set":authLabel}}
	  if binding.key?("birth") && binding["birth"].key?("value")
	    loc_birth = binding["birth"]["value"]
	  	solr_doc["loc_birth_s"] = {"set":loc_birth}
	  	birthDate = getYear(loc_birth)
	  	if !birthDate.nil?
	  		solr_doc["loc_birthy_i"] = {"set":birthDate}
  		else
  			puts "Birth Date nil for " + auth
	  	end
	  end 
	  
	  if binding.key?("death") && binding["death"].key?("value")
	    loc_death = binding["death"]["value"]
	   	solr_doc["loc_death_s"] = {"set":loc_death}
	    deathDate = getYear(loc_death)
	  	if !deathDate.nil?
	  		solr_doc["loc_deathy_i"] = {"set":deathDate }
  		else
  			puts "Death date nil for " + auth
	  	end
	  end

	   ##Collection solr documents and push every 20000
	  solr_documents.push(solr_doc)
	  if solrcounter == 20000
	  	puts "adding 20000 , " + counter.to_s + " of " + results.length.to_s
	    solr = RSolr.connect :url => solr_url
	    solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	  	solrcounter = 0
	  	solr_documents = []	  	
	  end
	  
	end
	#if any solr documents left over go ahead and add those
	if solr_documents.length
		puts "adding left over " + solr_documents.length.to_s
		solr = RSolr.connect :url => solr_url
		solr.add solr_documents, :add_attributes => {:commitWithin => 10}
	end
	puts "done with processing " + filename
	
end


readProcessFile('lcbirth.json')
readProcessFile('lcdeath.json')
