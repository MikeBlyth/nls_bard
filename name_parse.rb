def name_parse(name)
  name = name.split('; ')[0]
  if name =~ /(.*), +(.*\.?) +(.*)/    # Last, First Middle
    parsed = {last: $1, first: $2, middle: $3}
    return parsed
  end
  if name =~ /(.*), +(.*)/    # Last, First
    parsed = {last: $1, first: $2, middle: ''}
    return parsed
  end
  if name =~ /^(\w*\.?) +(\w*\.?) +(.*)/ # First Middle Last
    parsed = {last: $3, first: $1, middle: $2}
    return parsed
  end
  if name =~ /^(\w*) +([^ ]*)$/      # First Last
    parsed = {last: $2, first: $1, middle: ''}
    return parsed
  end
  parsed = {last: name, first: '', middle: ''}
  return parsed

#/(.*), ((.*)\.? )?(.*)/  # Last=1, First=3|4, Middle=4 if $3 is defined
end

def name_parse_test
	tests = ['David Thoreau','Patton, General H. W.', 'Aristotle', "O'Reilly, J. Paxton", "Schellhas, Bob; Gingrich, Newt; Gillespie, Ed; Armey, Richard K.",
	   "Saint-Exupéry, Antoine de", "García Márquez, Gabriel", "Beth-Home, Sara", "Castañeda, Jorge G.", 'D. L. Eisenhower', 'Lyndon B. Johnson', "Meriç, Nezihe"]
	   
	tests.each do |t|
	  p = name_parse(t)
	  puts "#{t} => #{p[:first]}|#{p[:middle]}|#{p[:last]}"
	end
end

#name_parse_test