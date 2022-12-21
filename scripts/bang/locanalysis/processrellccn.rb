require 'csv'
require 'net/http'
require 'json'
require 'set'

#Each line has a property, followed by ISBNs separated by commas
def check_file_grouped(filename, id_type)		
  isbn_set = Set.new
  row_count = 0
  total_row_count = 0
  #Overall, we also want to keep count of how many rows per property
  prop_total_row_count = {}
  #We also want to keep count of how many ISBNs per property? (perhaps groupings are enough?)
  # To do: actually store set of isbns 
  prop_total_isbn_set_hash = {}
  prop_match_row_count = {}
  prop_match_isbn_set_hash = {}
  match_isbn_set = Set.new
  
  #Also keep track of which identifier sets did not result in a match
  unmatched_set = []
  singlematch_set = []
	CSV.foreach(filename, headers: false) do |row|
      #First element in array will be URI so remove
      row_a = row.to_a   
      prop_name = row_a[0]
      #puts "Property name= " + prop_name  
	    ids = row_a.drop(1).uniq
      #puts "IDS =" + ids.to_s
      # Leave out rows with only one ISBN
      # Add ids to set
      if(ids.length > 1)
        # Number of total rows
        total_row_count += 1
        #Keep track of ISBN total
        isbn_set.merge(ids)
        # For property, keep track of total row
        if(!prop_total_row_count.has_key?(prop_name))
          prop_total_row_count[prop_name] = 0
        end
        prop_total_row_count[prop_name] += 1
        # By property, group together ISBNs to get total ISBNs related to an individual property
        if(!prop_total_isbn_set_hash.has_key?(prop_name))
          prop_total_isbn_set_hash[prop_name] = Set.new
        end
        prop_total_isbn_set_hash[prop_name].merge(ids)       
        res = query_solr(ids)
	  	  # Return results greater than one, i.e. at least two matches
		    if(check_match_qty(res, 1))
			    #puts row.to_a.join(",")
          row_count += 1
          match_isbn_set.merge(ids)
          #Also for property
          if(!prop_match_row_count.has_key?(prop_name))
            prop_match_row_count[prop_name] = 0
          end
          prop_match_row_count[prop_name] += 1
          # By property, group together ISBNs to get total ISBNs related to an individual property
          if(!prop_match_isbn_set_hash.has_key?(prop_name))
            prop_match_isbn_set_hash[prop_name] = Set.new
          end
          prop_match_isbn_set_hash[prop_name].merge(ids)
          #puts "Match exists"
          puts prop_name + " : " + ids.join(",")
        elsif(check_match_qty(res, 0))
          #only one match
          singlematch_set.push(prop_name + " : " + ids.join(","))
        else
        #No match for this line that contains more than one identifier
          unmatched_set.push(prop_name + " : " + ids.join(","))
	      end
      end
 end
 
 # Do some property maps to get counts by prop for totals and catalog matches

 prop_total_isbn_c = prop_total_isbn_set_hash.map { |k,v| [k, v.length.to_s] }.to_h
 prop_match_isbn_c = prop_match_isbn_set_hash.map { |k,v| [k, v.length.to_s] }.to_h
 puts "---TOTAL--"
 puts "total row count:" + total_row_count.to_s
 puts "total unique lccn count:" + isbn_set.length.to_s
 puts "total row count by property count:" + prop_total_row_count.to_s
 puts "total lccn by property count:" + prop_total_isbn_c.to_s
 
 puts "--MATCH--"
 puts "Matching row count:"+ row_count.to_s
 puts "Matching lccn count:" + match_isbn_set.length.to_s
 puts "Matching row count by property count:" + prop_match_row_count.to_s
 puts "Matching lccn by property count:" + prop_match_isbn_c.to_s
 puts "--Single match rows--"
 singlematch_set.each do|u|
   puts u.to_s
 end
 puts "--Unmatched rows--"
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
	# Replace with Solr index for your own work.  This index is a copy of our production catalog index
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	solr_url= base_url + "/select?q=lc_controlnum_s:(" + solr_query + ")&wt=json&fl=id,lc_controlnum_s&rows=20"
  #puts solr_url
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
	# Replace with Solr index for your own work.  This index is a copy of our production catalog index
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	solr_query = "\"" + ids.join("\" OR \"") + "\""
	solr_url= base_url + "/select?q=lc_controlnum_s:" + solr_query + "&wt=json&fl=id,lc_controlnum_s&rows=20"
	puts solr_url
end

check_file_grouped("prophublccnsets.csv", "lccn") 
