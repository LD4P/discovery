require 'csv'
require 'net/http'
require 'json'
require 'set'

# Process sets of LCCNs to check which are in the catalog and not
#Each line has LCCNs separated by commas
def check_file_grouped(filename)		
  lccn_set = Set.new
  
  row_count = 0
  total_row_count = 0
  match_lccn_set = Set.new
  unmatched_set = []
  singlematch_set = []
	CSV.foreach(filename, headers: false) do |row|
      #First element in array will be URI so remove
	    ids = row.to_a.uniq
      # Leave out rows with only one lccn
      # Add ids to set
      if(ids.length > 1)
        total_row_count += 1
        lccn_set.merge(ids)
        #lccn_count += ids.length
        res = query_solr(ids)
	  	  # Return results greater than one, i.e. at least two matches
		    if(check_match_qty(res, 1))
			    #puts row.to_a.join(",")
          row_count += 1
          match_lccn_set.merge(ids)
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
 puts "total unique lccn count:" + lccn_set.length.to_s
 puts "Matching row count:"+ row_count.to_s
 puts "Matching lccn count:" + match_lccn_set.length.to_s
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


#Cross-check against all opera that have multiple lccns

# Do a solr query with lccn array using OR and quote
def query_solr(lccns)
	results = []
	lccn_slices = [lccns]
	if(lccns.length > 30)
		lccn_slices = lccns.each_slice(30).to_a
	end
	lccn_slices.each do |is|
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
	# This is the SOLR URL for our copy of the catalog index.  Replace with the Solr URL you wish to query.
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	solr_url= base_url + "/select?q=lc_controlnum_s:(" + solr_query + ")&wt=json&fl=id,lc_controlnum_s&rows=20"
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

#lccnout.csv: Any id that shows up in a line - entire line constitutes a set
#Iterate through all ids

def process_lccn_out(filename)
	#lccn to index in array where set exists
	lccn_hash = {}
	#Array of sets where each set represents lccn grouping
	lccn_sets = []
	CSV.foreach(filename, headers: false) do |row|
	    ids = row.to_a
	    array_index = -1
	    ids.each do |i|
	    	#If we've encountered lccn before, which set is it added to
	    	if(lccn_hash.key?(i))
	    		array_index = lccn_hash[i]
	    		break
	    	end
	    end
	    #If none  of the items on this line have been added to our sets,need to create
	    if(array_index == -1)
	    	array_index = lccn_sets.length
	    	lccn_sets << Set.new  
	    end
	    ids.each do |i|
	    	lccn_sets[array_index].add(i)
	    	lccn_hash[i] = array_index
	    end
	   
	  	#res = query_solr(ids)
		#if(check_match_qty(res, 1))
		#	puts row.to_s
		#end
    end	
   lccn_sets.each do|iset|
   	#puts "set"
   	puts iset.to_a.join(",")
   end
   #puts lccn_hash.to_s
end

check_file_grouped("querylccngroups") 
