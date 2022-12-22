#require 'rubygems'
require 'zip'
require 'csv'
require 'net/http'
require 'json'
require 'set'


#Headers 
headers = "000,001,007,008,010$a,010$z,015,017,020,020$a,022,024,028,035$a,041$a,100$a,100$b,110,111$a,111$n,111$d,111$c,130,245,245$a,245$b,245$c,245$h,245$k,250$a,250$b,260$a,260$b,260$c,260$e,260$f,260$d,260$g,261,262,264,300$a,338,490,490$v,650,710,758,760,762,776,777$a,777$b,777$c,777$d,996$a,996$9"

# Read in CSV
csv_file = "singlematchisbn"
isbn_set = Set.new
# Read it into a set to allow for easily checking
CSV.foreach(csv_file, headers: false) do |row|
      #First element in array will be URI so remove
      row_a = row.to_a     
      ids = row.uniq
      isbn_set.merge(ids)
end

#puts isbn_set.length.to_s


# Read in POD Data
#file_location = "../outputs/csv-output/stanford-output-csv.zip"
#file_location = "../outputs/csv-output/harvard-output-csv.zip"
#file_location = "../outputs/csv-output/chicago-output-csv.zip"
#file_location = "../outputs/csv-output/duke-output-csv.zip"
#file_location = "../outputs/csv-output/dartmouth-output-csv.zip"

#file_location = "../outputs/csv-output/brown-output-csv.zip"
#file_location = "../outputs/csv-output/columbia-output-csv.zip"
file_location = "../outputs/csv-output/penn-output-csv.zip"


#Fields to check
ctr = 0
isbn_col = "020"
isbn_acol = "020$a"

# Matching rows
match_rows = []

Zip::File.open(file_location) do |zip_file|
  # Handle entries one by one
  zip_file.each do |entry|
    #if (entry.file? && ctr == 0)
    if (entry.name.end_with?(".txt"))
      #puts "known"
      #ctr = ctr + 1
      # Read in file
      #puts "#{entry.name} is a regular file!"

      # Read into memory
      content = entry.get_input_stream.read
      #puts "#{entry.name}"
      # From https://stackoverflow.com/questions/34815359/opening-a-zip-file-that-contains-a-csv-file-to-use-in-a-rake-task
      #csv = CSV.parse(content, :headers=>true) 
      #headers =  csv.headers.to_a.join(",")
      csv = CSV.parse(content, :headers=>true) do |row|
        #puts "020: " + row[isbn_col]
        #puts "020$a:" + row[isbn_acol]
        # Examples: 020: 9781510724327(alk. paper);151072432X(alk. paper);9781510724334(ebook)
        #020$a:9781510724327;151072432X
        col_a = row[isbn_col].nil? ? [] : row[isbn_col].split(";")
        cola_a = row[isbn_acol].nil? ? [] : row[isbn_acol].split(";")
        isbns_src = col_a.concat(cola_a)
        #puts isbns_src.to_s
        #include_isbns = isbns_src.any? {|i| test_set.include?(i)}
        include_isbns = isbns_src.any? {|i| isbn_set.include?(i)}
        if(include_isbns)
          match_rows << row
        end
      end
      
      # Output
      #puts content
    else
      #puts "#{entry.name} is something unknown, oops!"
    end
  end
end

# Print out results
if(match_rows.length > 0)
  puts headers
  match_rows.each { |row| puts row }
end
