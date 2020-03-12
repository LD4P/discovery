require 'json'

filename = 'callnumber_map.properties'
callnumbers = {}
callhierarchy = {}
line_num=0
text=File.open(filename).read
text.each_line do |line|
  if line_num >= 4
  	vals = line.split("=")
  	#puts vals.to_s
  	if(vals.length == 2)
  	  key = vals[0].strip
  	  callnumbers[key] = vals[1].strip.gsub("\n","")
  	  #if key has length 2, and matching parent key does not exist, then create parent key
  	  if(key.length == 1 && ! callhierarchy.key?(key)) 
  	  	callhierarchy[key] = []
  	  end
  	  if(key.length >= 2)
  	    keyprefix = key[0..0]
  	    if(! callhierarchy.key?(keyprefix))
  	    	callhierarchy[keyprefix] = []
  	    end
  	    keyval = key[0..1]
  	    if ! callhierarchy[keyprefix].include?(keyval) 
  	    	callhierarchy[keyprefix] << keyval
  	    end
  	  end
  	end
  end
  line_num += 1
end

callkeys = callnumbers.keys
#callkeys.each do |key|

#end

puts callnumbers.to_json
puts "hierarchy"

puts callhierarchy.to_json