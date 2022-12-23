require 'csv'
require 'net/http'
require 'json'


# Read in file to check for lccn matches

def check_file(filename)
	
	num_matches = 0
	File.foreach(filename) do |line|
		isbn_hash = parse_line(line.delete("\n"))
    comp_result = compare_sides(isbn_hash[:left], isbn_hash[:right])
		#puts isbn_hash.to_s
		# query solr for left side and for right side  
    if(comp_result[:ind])
  		left_r = query_solr(isbn_hash[:left])
  		right_r = query_solr(isbn_hash[:right])
      
  		match_found = check_solr_results(left_r, right_r)
  		if(match_found)
        num_matches += 1
  			puts line.delete("\n")
  			#puts "\"" + isbn_hash[:left].join("\" OR \"") + "\""
  			#puts "\"" + isbn_hash[:right].join("\" OR \"") + "\""
  		end
    end
	
	end 
  puts num_matches
end

# Parse the line to get ISBNs, ones on left and ones on right
def parse_line(line)    
	#puts "line"
	#puts line
	components = line.split("|")
	# Left most
	left_component = components[0].slice(1..-2)
	right_component = components[2]
	left_array = left_component.split(",")
	right_array = right_component.split(",")
	return {"left":left_array, "right":right_array} 
end

# Do a solr query with ISBN list using OR and quote
def query_solr(isbns)
  # This is the Solr URL for our copy of the production Solr index.  Replace with the Solr URL you wish to query
	base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
	orig_isbns = isbns
	if(isbns.length > 30)
		isbns = isbns.slice(0, 30)
	end
	solr_query = "\"" + isbns.join("\" OR \"") + "\""
  	#solr_query = isbns.join(" OR ") 
  	solr_url= base_url + "/select?q=isbn_t:" + solr_query + "&wt=json&fl=id,isbn_t&rows=20"
  	url = URI.parse(solr_url)
    resp = Net::HTTP.get_response(url)
    data = resp.body
    result = JSON.parse(data)
    return result
end

def check_solr_results(left_results, right_results)
	return (has_docs(left_results) and has_docs(right_results))
end

def has_docs(result)
	return(result.key?("response") and result["response"].key?("numFound") and result["response"]["numFound"].to_i > 0)
end

def compare_sides(left_r, right_r)
  #Is left side completely represented on right?
  left_contained = left_r - right_r
  right_contained = right_r - left_r
  independent = !(left_contained.empty?) && !(right_contained.empty?)
  #Independent is true if no overlap, false if either left or right is contained
  return {"ind":independent, "lc":left_contained.empty?, "rc":right_contained.empty?}
end

check_file("isbnworkrelmatches")