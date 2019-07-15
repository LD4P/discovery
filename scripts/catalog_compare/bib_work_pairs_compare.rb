require 'json'
require 'net/http'
require 'httparty'

# This script interates over an input file of OCLC work ids and bib ids. 
# Each work id is queried against Wikidata's SPARQL API. The resulting
# title and Q number (for reconstructing a Wikidata URI) are recorded.

def get_pairs
  # open and parse a tab-seperated file with a list of OCLC work id and bib ids
  pairs_file = File.read('bib_work_pairs.dat')
  file_lines = pairs_file.split("\n").reject{|i| i[0] == '#'} # skip comment lines
  pairs_data = file_lines.map{|i| i.split(' ')}
  return pairs_data
end

def lookup_works(works)
  # given an array of pairs of [work_id, bib_id] look up each and write result
  for work in works
    sleep(3) # slow the rate at which we hit the API
    work_id = work.first
    bib_id = work.last
    begin
      q_num_and_title = sparql_request(work_id)
      write_file(bib_id, work_id, q_num_and_title)
    rescue
      puts "*** connection error retry ***"
      retry
    end
    
  end
end

def sparql_request(work_id)
  # compose a query asking for a book title by OCLC work id number
  sparql_query = '
SELECT ?item ?itemLabel
WHERE {
  SERVICE wikibase:label {
    bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en".
  }
  ?item wdt:P5331 "'+work_id.to_s.strip+'".
}'
  # set up wikidata connection
  uri_string = "https://query.wikidata.org/sparql?query=#{sparql_query}&format=json"
  uri_encode = URI.encode(uri_string)
  user_agent = 'CornellUniversityLibraryLD4P2/0.1 (jss543@cornell.edu)'
  # make a request to wikidata and parse the response
  response_json = HTTParty.post(uri_encode, {headers: {"User-Agent" => user_agent}})
  response_hash = JSON.parse(response_json)
  # if found in wikidata, return a book pair: uri and title
  bindings = response_hash["results"]["bindings"]
  if bindings.length > 0
    output = [
      bindings.first["item"]["value"], # wikidata uri
      bindings.first["itemLabel"]["value"] # title
    ]
  end
  return output if output
  return false
end

def write_file(bib_id, work_id, q_num_and_title)
  filename = 'bib_work_pairs_compare_output.txt'
  line = [bib_id, work_id]
  if q_num_and_title
    line = line + q_num_and_title
  end
  line_string = line.join(', ') + "\n"
  File.write(filename, line_string, mode: 'a')
  puts line_string # also display output lines in terminal
end

# run the script
works = get_pairs # open and parse the .dat file of pairs
lookup_works(works) # lookup works in file and write output

