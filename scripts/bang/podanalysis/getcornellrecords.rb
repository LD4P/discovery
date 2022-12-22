require 'csv'
require 'net/http'
require 'json'
require 'set'

#For each set of ISBNs, retrieve catalog id, title, and the ISBNs for that record and output all of them
#This supposes only one catalog match per record
def get_records(filename)		
 
	CSV.foreach(filename, headers: false) do |row|
	    ids = row.to_a.uniq
      if(ids.length > 1)
        #Query solr
        res = query_solr(ids)
        #id, title_display, isbn_t
        res.each do |result|
		      if(result.key?("response") && result["response"].key?("docs") && result["response"]["docs"].length > 0)
                docs = result["response"]["docs"]
                docs.each do |d|
                  doc_id = d["id"]
                  title = d["title_display"]
                  isbns = d["isbn_t"].join(",")
                  puts ids.join(",") + "|" + doc_id + "," + title + "|" + isbns
                end
          end
	      end
        
	  	 
      end
 end
 
end


# Do a solr query with ISBN array using OR and quote
def query_solr(isbns)
	results = []
	isbn_slices = [isbns]
	if(isbns.length > 30)
		isbn_slices = isbns.each_slice(30).to_a
	end
	isbn_slices.each do |is|
		# Get rid of nils or empty strings
		query_ids = is.reject { |item| item.nil? || item == '' }
		#Get rid of non-ascii characters
		query_ids = query_ids.map { |s| s.delete("^\u{0000}-\u{007F}") }
		# Get rid of white space
		query_ids = query_ids.collect(&:strip)
		#puts query_ids.to_s
		#Remove nils or empty strings
		solr_query = "\"" + query_ids.join("\" OR \"") + "\""
  		results << execute_solr_query(solr_query)
	end
	return results
end

def execute_solr_query(solr_query)
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	solr_url= base_url + "/select?q=isbn_t:" + solr_query + "&wt=json&fl=id,isbn_t,title_display&rows=20"
  	url = URI.parse(solr_url)
    resp = Net::HTTP.get_response(url)
    data = resp.body
    result = JSON.parse(data)
    return result
end

def check_match_qty(results, target)
	total_results = 0
	results.each do |res|
		total_results += get_num_found(res)
	end
   return (total_results > target.to_i)

end
def get_num_found(result)
	num_found = 0
	if(result.key?("response") and result["response"].key?("numFound"))
		num_found = result["response"]["numFound"].to_i
	end
	return num_found
end


get_records("singlematchisbn") 
