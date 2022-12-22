require 'zip'
require 'csv'
require 'net/http'
require 'json'
require 'set'

#This queries sets of ISBNs and outputs Cornell matches as well as matches from the POD index
def read_file
  # Read in CSV
  csv_file = "../singlematchisbn"
  html_display = ["<html><meta charset='UTF-8'><head></head><body>"];
  # Read it into a set to allow for easily checking
  CSV.foreach(csv_file, headers: false) do |row|
        row_a = row.to_a     
        ids = row.uniq
        #puts ids.to_s
        # First, query Cornell
        cornell_results = query_solr(ids, "Cornell")
        cornell_display = process_solr_results(cornell_results, "Cornell")        
        # Then query pod
        pod_results = query_solr(ids, "POD")
        pod_display = process_solr_results(pod_results, "POD")  
        # Put the HTML together
        html_display.push(generate_html_group(ids, cornell_display.join("") + pod_display.join("") ) + "<br>")
        
  end
  html_display << "</body></html>";
  puts html_display.join("")
end


def process_solr_results(res, source)		
  #id, title_display, isbn_t
  html_array = []
  res.each do |result|
    if(result.key?("response") && result["response"].key?("docs") && result["response"]["docs"].length > 0)
          docs = result["response"]["docs"]
          html_array << generate_html_results(docs, source)          
    end
  end
  return html_array
 
end

def generate_html_results(docs, source)
  html_array = []
  if(source == "Cornell")
    docs.each do | doc|
      html_array.push("Cornell: <a href='http://newcatalog.library.cornell.edu/catalog/" + doc["id"] + "'>" + doc["title_display"] + "</a><br>")
    end
  elsif(source == "POD")
    docs.each do | doc|
      institution = doc["institution_s"]
      control_num = doc["001_ss"].join(",")
      #puts institution + ":" + control_num
      link = get_institution_url(control_num, institution) 
      html_array.push(institution + ": <a href='" + link + "'>" + doc["245_ss"].join(",") + "</a><br>")
    end
  end
  return html_array.join(" ")
end

def get_institution_url(control_num, institution) 
  link = ""
  id = control_num
  if(institution == "Stanford")
    #Strip a at beginning of number
    if(control_num.start_with?("a"))
      id = control_num.delete_prefix("a")
    end
    link = "https://searchworks.stanford.edu/view/" + id
  elsif (institution == "Harvard")
    link = "http://id.lib.harvard.edu/alma/" + id + "/catalog"
  elsif (institution == "Chicago")
    link = "https://catalog.lib.uchicago.edu/vufind/Record/" + id
  elsif (institution == "Duke")
    link = "https://find.library.duke.edu/catalog/" + id
  elsif (institution == "Dartmouth")
    link = "https://search.library.dartmouth.edu/permalink/01DCL_INST/16rgcn8/alma" + id
  elsif (institution == "Columbia")
    link = "https://clio.columbia.edu/catalog/" + id
  elsif (institution == "Brown")
    #Issues with 001 field in POD record not corresponding to 001 field in Brown source record
    if(id.start_with?("ocm"))
      id = id.delete_prefix("ocm")
    elsif(id.start_with?("ocn"))
      id = id.delete_prefix("ocn")
    elsif(id.start_with?("on"))
      id = id.delete_prefix("on")
    end
    link = "https://bruknow.library.brown.edu/discovery/search?query=any,contains," + id + "&tab=Everything&search_scope=MyInst_and_CI&vid=01BU_INST:BROWN&lang=en&offset=0"
  elsif (institution == "Penn")
    link = "https://franklin.library.upenn.edu/catalog/FRANKLIN_" + id
  end
  return link
end
def generate_html_group(isbns, results_html)
  return "<div>ISBNS: " + isbns.join(",") + "<div>" + results_html + "</div></div>"
end


# Do a solr query with ISBN array using OR and quote
def query_solr(isbns, source)
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
  		results << execute_solr_query(solr_query, source)
	end
	return results
end

def execute_solr_query(solr_query, source)
  if(source == "Cornell")
    # The Solr URL for our copy of production Solr.   Pleae replace with your own Solr URL
    base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/blacklight"
    solr_url= base_url + "/select?q=isbn_t:" + solr_query + "&wt=json&fl=*&rows=20"
  else
    # The Solr URL for our copy of production Solr.   Pleae replace with your own Solr URL
    base_url =  "http://ld4p3-folio-solr.library.cornell.edu/solr/POD"
    solr_url= base_url + "/select?q=020_a_ss:(" + solr_query + ") OR 020_ss:(" + solr_query + ")&wt=json&fl=*&rows=20&sort=institution_s asc"
  end
	
    url = URI.parse(solr_url)
    resp = Net::HTTP.get_response(url)
    data = resp.body
    result = JSON.parse(data)
    return result
end

def generate_html_display(isbns, institutional_data)

end

read_file()