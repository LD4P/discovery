#require 'rubygems'
require 'zip'
require 'csv'
require 'net/http'
require 'json'
require 'set'
require 'rsolr'


#Headers 
headers = "000,001,007,008,010$a,010$z,015,017,020,020$a,022,024,028,035$a,041$a,100$a,100$b,110,111$a,111$n,111$d,111$c,130,245,245$a,245$b,245$c,245$h,245$k,250$a,250$b,260$a,260$b,260$c,260$e,260$f,260$d,260$g,261,262,264,300$a,338,490,490$v,650,710,758,760,762,776,777$a,777$b,777$c,777$d,996$a,996$9"
def updateIndex(solr_documents)
   # This is the Solr index we used for this work.  We created the POD Solr collection to contain the data. 
   solr_url = "http://ld4p3-folio-solr.library.cornell.edu/solr/POD"
   solr = RSolr.connect :url => solr_url
   solr.add solr_documents, :add_attributes => {:commitWithin => 10}
end
 
# Read in POD files from directory

def read_directory
  solr_docs = []
  institutions = {"Harvard" => "./results/hrvdresults_hubisbn",
  "Stanford" => "./results/stfodresults_hubisbn",
  "Chicago" => "./results/chicagoresults_hubisbn",
  "Duke" => "./results/dukeisbnresults",
  "Dartmouth" => "./results/dartmouthisbnresults",
  "Columbia" => "./results/columbiaisbnresults",
  "Brown" => "./results/brownisbnresults",
  "Penn" => "./results/pennisbnresults" } 
  
  error_display = []

  institutions.each do |name, file_path|
    CSV.foreach(file_path, headers: true) do |row|
      #Move along if 001 field empty, but log it
      if (row["001"].nil?)
        error_display.push(name + ": " + row.to_s)
        next
      end
      #
      solr_doc = {"institution_s": name}
      #First element in array will be URI so remove
      row_headers = row.headers
      row_headers.each do |header|
        if(header == "001")
          solr_doc["id"] = name + row[header]
        end 
        field_name = header.gsub("$","_") + "_ss"
        field_value = row[header]   
        #If 020 or 020$a, values are separated by semicolon
        if( (!field_value.nil?) && (header == "020" || header == "020$a"))
          field_value = field_value.split(";")
          field_value = field_value.collect(&:strip)
          #puts "header is 020"
          #puts field_value
        end  
        if(! field_value.nil?)        
          solr_doc[field_name] = field_value
        end
      end
      #puts solr_doc.to_s
      solr_docs << solr_doc
    end
  end
  
  #puts solr_docs.to_s
  updateIndex(solr_docs)
  puts "updated index"
  puts "Missing 001 fields: These rows were not included"
  error_display.each {|e| puts e}
end

read_directory();