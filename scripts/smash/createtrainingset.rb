require 'json'
require 'net/http'
require 'open-uri'

def processFile(filename)
 # use environment variable or argument, example solr below
 solrurl = "http://example.org?subject_collection/select?wt=json&q=label_s:"
 
 file = File.read(filename)
 data = JSON.parse(file)
 
 docs = data["response"]["docs"]
 
 tsv = []
 rowcount = 0
 counter = 0
 puts "original number " + docs.length.to_s
 docs.each do |doc|
 
 	rowcount = rowcount + 1
 	counter = counter + 1
 	fulltitle = doc["fulltitle_display"]
 	## Using subject_display and will just match against lcsh for now
 	## replace " > " with "--"
 	subject = doc["subject_display"]
 	if !subject.nil? && subject.length 
 		row = []
		#row = [fulltitle]
 		uris = []
		subject.each do|s|
 			sub = s.gsub ' > ', '--'
 			#check if index has matching subject
 			# URI::encode
 			queryurl = solrurl + "\"" + URI::encode(sub) + "\""
 			#puts queryurl
 			url = URI.parse(queryurl)
 			req = Net::HTTP::Get.new(url.to_s)
 			res = Net::HTTP.start(url.host, url.port) {|http|
 			  http.request(req)
 			}
 			resbod = res.body
 			resobj = JSON.parse(resbod)
 			if(resobj.key?("response") && resobj["response"].key?("docs") && resobj["response"]["docs"].length > 0)
 				resdoc = resobj["response"]["docs"][0]
 				uri = resdoc["uri_s"]
				if !uri.nil? && uri.length > 0
 					uris << uri
				end
 			end
 			
 		end
		if uris.length > 0
			row = [fulltitle]
			row += uris
 			tsv << row.join("\t")
		end 
 	end
    if rowcount == 20000
 	  	puts "adding 20000 , " + counter.to_s 
 	    # Writing to the file
       File.open("subjecttrainres.tsv", "a") { |file| file.write tsv.join("\n") + "\n" }
       # reset
 	  	rowcount = 0
 	  	tsv = []	  	
 	  end 
 end
 
 if tsv.length
   puts "Writing remaining " + tsv.length.to_s
   File.open("subjecttrainres.tsv", "a") { |file| file.write tsv.join("\n") + "\n"}
 end

end

#We had several files so processed them one by one


#puts "Starting processing of solrraw.json"
#processFile("solrraw.json")

#puts "Ended processing file solrraw"
#puts "Solr raw 1"
#processFile("solrraw1.json")
#puts "Ended processing solrraw1"
#puts "Solr raw 2"
#processFile("solrraw2.json")
#puts "Ended processing solrraw2"
puts "Solr raw 3"
processFile("solrraw3.json")
puts "Ended processing solrraw3"
