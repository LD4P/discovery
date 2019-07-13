require 'json'
require 'net/http'
require 'httparty'

# This script interates over an input file of OCLC work ids queried from Cornell's
# Solr cataloge. Each work id is queried against Wikidata's SPARQL API. Each work
# that is found in Wikidata has its title recorded and compared to the Solr title.

def get_solr_works
  # open and parse a json file with a list of book titles and OCLC work id nubmers
  file = File.read('solr_ids.json')
  file = '{'+file+'}' unless file[0] == '{' # ensure json is wrapped in {}
  shsh = JSON.parse(file)
  return shsh["response"]["docs"]
end

def lookup_works(works)
  # given a hash of titles and work ids, query each work id and write results
  for work in works
    sleep(1) # slow the rate at which we hit the API
    id_num = work["work_id"].first
    result = sparql_request(id_num)
    title_mismatch = title_mismatch?(result, work["title"])
    write_file(id_num, result, title_mismatch)
  end
end

def sparql_request(id_num)
  # compose a query asking for a book title by OCLC work id number
  sparql_query = '
SELECT ?bookLabel
WHERE {
  ?book wdt:P5331 "'+id_num.to_s.strip+'".
  SERVICE wikibase:label {
  bd:serviceParam wikibase:language "en" .
  }
}'
  # set up wikidata connection
  uri_string = "https://query.wikidata.org/sparql?query=#{sparql_query}&format=json"
  uri_encode = URI.encode(uri_string)
  user_agent = 'CornellUniversityLibraryLD4P2/0.1 (jss543@cornell.edu)'
  # make a request to wikidata and parse the response
  response_json = HTTParty.post(uri_encode, {headers: {"User-Agent" => user_agent}})
  response_hash = JSON.parse(response_json)
  # return a book title if one was returned by wikidata
  bindings = response_hash["results"]["bindings"]
  return bindings.first["bookLabel"]["value"] if bindings.length > 0
  return false
end

def write_file(id_num, result, title_mismatch)
  filename = 'solr_oclc_compare_output.txt'
  line = id_num
  if result # only write title if it was found
    line << ', '
    line << result.to_s
    if title_mismatch
      line << ', '
      line << title_mismatch
    end
  end
  line << "\n"
  File.write(filename, line, mode: 'a')
  puts line # also display output lines in terminal
end

def title_mismatch?(a, b)
  return false if a == false
  return false if a.to_s.strip == b.to_s.strip
  return "** title mismatch **"
end

# run the script
works = get_solr_works # open and parse json file
lookup_works(works) # lookup works in file and write output

