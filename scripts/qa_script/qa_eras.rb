require 'json'
require 'net/http'
require 'httparty'

# This script interates over an input file of Cornell catalog subject eras.
# Each era is checked against the Questioning Authority (QA) server.

# Usage of the script:
# sudo gem install httparty
# ruby qa_eras.rb

# Subject eras can be found here:
# https://newcatalog.library.cornell.edu/catalog/facet/fast_era_facet?&q=*.*

def get_eras
  # open and parse a file with one subject era per line
  return File.read('input.txt').split("\n")
end

def lookup_era(eras)
  # look up each subject era string in QA and record the response
  for era in eras
    sleep(1) # slow the rate at which we hit API
    qa_response = qa_request(era)
    write_file(era, qa_response)
  end
end

def qa_request(era)
  # set up QA connection
  uri_string = "https://lookup.ld4l.org/authorities/search/linked_data/oclcfast_direct/period?q=#{era}&maxRecords=4"
  uri_encode = URI.encode(uri_string)
  # make a request to QA
  qa_response = HTTParty.get(uri_encode)
  return qa_response.body
end

def write_file(era, qa_response)
  file = 'output.txt'
  line = "#{era.ljust(30)}\t#{qa_response}"[0..500]+"\n" # limit output to 120 characters
  File.write(file, line, mode: 'a')
  puts line # also display output lines in terminal
end

# run the script
eras = get_eras # open and parse the .txt file subject eras
lookup_era(eras) # lookup strings in QA and write output



