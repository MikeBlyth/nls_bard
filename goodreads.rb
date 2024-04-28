require 'nokogiri'
require 'httparty'
require 'pry'
#require 'namae'
require './name_parse.rb'

def double_quote(title)
	return '"' + title.gsub(/\"/,'') + '"' # Remove internal quotes, surround with quotes
end

def goodreads_url(title, author)
	author_url = URI.encode(author.strip)
	title_url = URI.encode(title.strip)
	title_url = URI.encode(double_quote(title.strip))  # Experimental! Helps get exact match?
	full_url =  "https://www.goodreads.com/search?q=#{title_url}+#{author_url}"
	return full_url
end

def get_goodreads_page(title, author)
 #   puts "  -- trying #{title} by <#{author}>"
	request_url = goodreads_url(title, author)
	page = HTTParty.get(request_url)
	return Nokogiri::HTML(page)
end

def chrome_goodreads_page(title, author)
byebug
    @goodreads_driver = @goodreads_driver || init_chromium_driver # set up chrome instance if it's not open
	request_url = goodreads_url(title, author)
    @goodreads_driver.navigate.to request_url
end


def goodreads_not_found(parsed_page)
		return ((parsed_page.xpath("//h3[contains(., 'No results')]").to_a != []) ||
				parsed_page.xpath("//div[@class='suggestionSmall'][contains(., 'No results found for')]").to_a != [])
end

def get_goodreads_info # Manually (from operator) Get the title, author, and rating actually displayed on page
	return {:match => false} unless $manual_update  # For unattended updates, don't get user input
	print "Goodreads title: "
	goodreads_title = gets.strip
	return {goodreads_title: 'ignore'} if (goodreads_title.downcase == 'i') || (goodreads_title.downcase == 'ignore')

	print "Goodreads author: "
	goodreads_author = gets.strip
	print "Stars: "
	stars_string = gets.strip
    print "Ratings: "
	ratings_string = gets.strip
    # Make hash etc, handle, return
	return {goodreads_title: goodreads_title, goodreads_author: goodreads_author, stars: stars_string.to_f, count: ratings_string.to_i, match: true}
end

def author_strings(author)
	parsed =  name_parse(author)
	first = parsed[:first]
	last = parsed[:last]
	byebug if (last || '') == ''
	middle = parsed[:middle]
	search_strings = []
	if middle > ''
      search_strings << "#{first} #{middle} #{last}"
	end
	search_strings << "#{first} #{last}"
	search_strings << "#{last}"
	return search_strings
end

def punct_strip(s)
    if s =~ /(.*?)([ .,;:\-?$!]*$)/   # Ending punctuation
	  s = $1
	end
	return s
end

def title_strings(title)
	if title =~ /(.*): a novel/i
	  title = $1
	end
	if title =~ /^((The )|(A )|(An ))(.*)/  # Strip initial The, A, and An
	  title = $5
	end
	if title =~ /^\"(.*?)\"(.*)/ # Goodreads doesn't use quotes in the title
	  title = $1+$2
	end
	title.gsub!(/ :+ /,': ')
	search_strings = [punct_strip(title)]
	if title =~ /,/
	    search_strings << title.gsub(/,/,'')
	    search_strings << title.gsub(/,/,':')
    end
	if title =~ /:/
	    search_strings << title.gsub(/:/,'')
	    search_strings << title.gsub(/:/,',')
    end
	while title =~ /(.*)[,\.:(;\[]/  # Remove parts after a delimiter ". : ( ; ["
		title = punct_strip $1
		search_strings << title
    end
	if title =~ /\&/
		search_strings << title.gsub(/\&/,'and')
	end
	return search_strings
end

def original_or_goodreads_title(book)
    t = book[:title]
	g = book[:goodreads_title]
	if g && (g > '') &&  (g != 'ignore') && (g != 'no match xxx')
	  t = g
	end
	return t
end

def goodreadsRating(book)
    # Use the goodreads_title and _author fields if they exist; they're the best ones for searching goodreads
	gr_auth = (book[:goodreads_author] || '').strip # there may be some stray fields with nil or ' ' instead of ''
	if gr_auth > ''
	  author = gr_auth
	  author_orig = author.clone
	else
	    author = book[:author] || ''
		if author =~ /(.*) \(.*\)/  # Get rid of parenthesized stuff in author name
		  author = $1
		end
		author_orig = author.clone
		if author =~ /(.* \w{2,})\./  # Get rid of trailing period that's not for an initial
		  author = $1
		end
	end
#    if (book[:goodreads_title] || '') > ''  # Use goodreads_title if it's defined
#	  title = book[:goodreads_title] unless (book[:goodreads_title] == 'ignore') || (book[:goodreads_title] == 'no match xxx')
#	else
#	  title = book[:title] || ''
#	end
	title = original_or_goodreads_title(book)
   # puts "Get rating for #{author}, #{title}"
	return nil if (title == '') || (author == '')
	author_array = author_strings(author)
    author_last_name = name_parse(author)[:last]
#	byebug if book[:key] == 'DB46708'
	title_array = title_strings(title)
	title_url = URI.encode(title.strip)
	not_found = true
	while (author_array.count > 0) && (not_found) # Keep using smaller chunks of author's name until a match is found
    	author_try = author_array.shift
	    parsed_page = get_goodreads_page(title, author_try)
		not_found = goodreads_not_found(parsed_page)
    end
	not_found = true
	while (title_array.count > 0) && (not_found) # Keep using smaller chunks of title until a match is found
    	title_try = title_array.shift
# puts "\tTrying #{title_try}"
	    parsed_page = get_goodreads_page(title_try, author_try)
		not_found = goodreads_not_found(parsed_page)
    end
	if not_found
	  puts "No Goodreads match found for #{book[:key]} #{title} by #{author_orig}."
#	  byebug
	  if $manual_update
		chrome_goodreads_page(title, author_last_name)
		return get_goodreads_info
	  else
		return {:goodreads_title => 'no match xxx', :match => false}
	  end
	end

#	ratings = parsed_page.xpath("//span[@class='minirating']")
#    title_xpath = title.downcase.gsub(/\'/,'$')
#	byebug if author_last_name.nil?
#	author_xpath = author_last_name.downcase.gsub(/\'/,'$')
#    xpath_expr = "//a[@class='bookTitle']/span[@itemprop='name']//text()[contains(translate(., \"ABCDEFGHIJKLMNOPQRSTUVWXYZ\'\", 'abcdefghijklmnopqrstuvwxyz$'),'#{title_xpath}')]/ancestor::td/span[@itemprop='author']/div/a/span[contains(translate(., \"ABCDEFGHIJKLMNOPQRSTUVWXYZ\'\", 'abcdefghijklmnopqrstuvwxyz$'),'#{author_xpath}')]/ancestor::td//span[@class='minirating'][text()]"
	#byebug
    ratings = search_goodreads_entries(parsed_page,title, author_last_name)
	if ratings
#byebug if ratings.count > 1
		max_rating = get_stars(ratings) # Get the stars and count for the entry with the highest number of ratings (count)
		stars = max_rating[:stars]
		count = max_rating[:count]
		rating_info = {:stars=>stars, :count=>count, :goodreads_title => title, :goodreads_author => author_try, :match => true}
	else
	   puts "Rating not found for #{title} by #{author_orig}."
	   if $manual_update
		 chrome_goodreads_page(title, author)
	     rating_info = get_goodreads_info
	   else
         rating_info = {:goodreads_title => 'no rating xxx', :match => false}
       end
	end
	return rating_info
end

def get_stars(ratings) # Find highest rated entry among the array of matching minirating spans
    max_count = -1
	max_stars = 0
	ratings.each do |r|
		rating_string = r.children[1].to_s
		if rating_string =~ /([0-9\.]*) avg rating .* ([0-9\.,]*) rating/ then
			stars,count = $1.to_f, $2.gsub(/,/,'').to_i
			if count > max_count
				max_count = count
				max_stars = stars
			end
		end
	end
	return {stars: max_stars, count: max_count}
end

def search_goodreads_entries(parsed_page,title, author) # Returns array of <span class=minirating>...</span> elements containing ratings
    # If there is more than one matching Goodreads entry matching target title and author strings, all will be returned
	title_array = title_strings(title)
	author_xpath = author.downcase.gsub(/\'|\u2019/,'$').gsub(/\u201c|\u201d/, '"') # Replace single quotes with $ since can't use in xpath, curly quotes with straight
    found = false
    tr_in = "\"ABCDEFGHIJKLMNOPQRSTUVWXYZ\u2019\u201c\u201d\'\""
	tr_out= "'abcdefghijklmnopqrstuvwxyz$\"\"$'"
	tr_string = "translate(., #{tr_in}, #{tr_out})"
	while (title_array.count > 0) && (! found) # Keep using smaller chunks of author's name until a match is found
		title_xpath = title_array.shift.downcase.gsub(/\'/,'$')
		xpath_expr = "//a[@class='bookTitle']/span[@itemprop='name']//text()[contains(#{tr_string},'#{title_xpath}')]/ancestor::td/span[@itemprop='author']/div/a/span[contains(#{tr_string},'#{author_xpath}')]/ancestor::td//span[@class='minirating'][text()]"
		ratings = parsed_page.xpath(xpath_expr) # will be empty if not found
		found = ratings.count > 0
#		puts "#{title_xpath}: #{found}"
    end
    ratings = nil if ratings.count == 0
    return ratings
end
