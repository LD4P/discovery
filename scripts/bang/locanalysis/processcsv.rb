require 'csv'
require 'net/http'
require 'json'
require 'set'

#Each line has a URI followed by ISBNs separated by commas
def check_file_grouped(filename, id_type)		
  isbn_set = Set.new
  #hub_set = Set.new
  #isbn_count = 0
  row_count = 0
  total_row_count = 0
  match_isbn_set = Set.new
  unmatched_set = []
  singlematch_set = []
	CSV.foreach(filename, headers: false) do |row|
      #First element in array will be URI so remove
      row_a = row.to_a     
      #hub_set.add(row_a[0])
	    ids = row.to_a.drop(1).uniq
      # Leave out rows with only one ISBN
      # Add ids to set
      if(ids.length > 1)
        total_row_count += 1
        isbn_set.merge(ids)
        #isbn_count += ids.length
        res = query_solr(ids)
	  	  # Return results greater than one, i.e. at least two matches
		    if(check_match_qty(res, 1))
			    #puts row.to_a.join(",")
          row_count += 1
          match_isbn_set.merge(ids)
          puts ids.join(",")
         #only one match 
         elsif(check_match_qty(res, 0))
          #only one match
           singlematch_set.push(ids.join(","))
         else
        #No match for this line that contains more than one identifier
           unmatched_set.push(ids.join(","))
        end
      end
 end
 puts "----------------------------------------"
 puts "total row count:" + total_row_count.to_s
 puts "total unique isbn count:" + isbn_set.length.to_s
 puts "Matching row count:"+ row_count.to_s
 puts "Matching isbn count:" + match_isbn_set.length.to_s
 puts "-----------------------------------------"
 puts "--Single match rows--"
 puts "Count:" + singlematch_set.length.to_s
 singlematch_set.each do|u|
   puts u.to_s
 end
 puts "--Unmatched rows--"
 puts "Count:" + unmatched_set.length.to_s
 unmatched_set.each do|u|
   puts u.to_s
 end
 
end


#Cross-check against all opera that have multiple ISBNs

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
	# Replace with your own Solr URL.  This URL is for our copy of the catalog Solr index
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	solr_url= base_url + "/select?q=isbn_t:" + solr_query + "&wt=json&fl=id,isbn_t&rows=20"
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

#isbnout.csv: Any id that shows up in a line - entire line constitutes a set
#Iterate through all ids

def process_isbn_out(filename)
	#ISBN to index in array where set exists
	isbn_hash = {}
	#Array of sets where each set represents ISBN grouping
	isbn_sets = []
	CSV.foreach(filename, headers: false) do |row|
	    ids = row.to_a
	    array_index = -1
	    ids.each do |i|
	    	#If we've encountered isbn before, which set is it added to
	    	if(isbn_hash.key?(i))
	    		array_index = isbn_hash[i]
	    		break
	    	end
	    end
	    #If none  of the items on this line have been added to our sets,need to create
	    if(array_index == -1)
	    	array_index = isbn_sets.length
	    	isbn_sets << Set.new  
	    end
	    ids.each do |i|
	    	isbn_sets[array_index].add(i)
	    	isbn_hash[i] = array_index
	    end
	   
	  	#res = query_solr(ids)
		#if(check_match_qty(res, 1))
		#	puts row.to_s
		#end
    end	
   isbn_sets.each do|iset|
   	#puts "set"
   	puts iset.to_a.join(",")
   end
   #puts isbn_hash.to_s
end

def create_solr_query(idstring)
	ids = idstring.split(",")
	# Replace with your own Solr URL.  This URL is for our copy of the catalog Solr index
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	solr_query = "\"" + ids.join("\" OR \"") + "\""
	solr_url= base_url + "/select?q=isbn_t:" + solr_query + "&wt=json&fl=id,isbn_t&rows=20"
	puts solr_url
end

check_file_grouped("HubSets.csv", "isbn") 
