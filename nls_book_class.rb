require 'date'
require 'word_wrap'
require 'colorize'

class Book < Hash
  attr_accessor :category_array

  @@fields = [:author, :title, :stars, :ratings, :categories, :year, :awards, :target_age, :reading_time, :key, :blurb, :read_by]

  def fields
    @@fields
  end

  def to_s
    post_initialize
	return [self[:author], self[:title], self[:stars], self[:ratings], self[:categories], self[:year], self[:awards],
	   self[:target_age],self[:reading_time],
	self[:key], self[:blurb], self[:read_by]].join("|")
  end

  def display(screen_output = true)
    post_initialize
	title = self[:title]
	title = title.yellow if screen_output
	s = ["#{title} by #{self[:author]}. #{self[:year]}. #{self[:key]}" ,
		"#{self[:stars]} stars with #{self[:ratings]} ratings.",
		self[:blurb] + " Reading time #{self[:reading_time]} hours.",
	    self[:categories],
		]
	if self[:has_read]
	  s << "Read or downloaded #{self[:date_downloaded]}."
	end
	s.each {|s| puts WordWrap.ww(s,90)}
	puts
  end

  def description
    post_initialize
	title = self[:title]
	s = ["#{title}, by #{self[:author]}. Published in #{self[:year]}. ",
		"This book has #{self[:stars]} stars with #{self[:ratings]} ratings. ",
		"Description: " + self[:blurb] + " The reading time is #{self[:reading_time]} hours.",
		 "The NLS number is #{self[:key]}."]
	s.each {|t| puts t}
	puts
  end

  def first_name_first(author='')
   # if author =~ /([^,]+*), ([^;]+)(; .*)/
	# Try /([^,]+), ([^;]+)(, ((I+)|(Jr\.)))(; .*)?/ matches when Jr. or II but not otherwise. Adding ? makes Jr. get absorbed
  end

  def initialize(values = {title: '', author: '', categories: '', blurb: '', key: '', stars: 0, ratings: 0})
    return if values.nil?
    if values.is_a? Hash
	  values.each {|key, value| self[key] = value}
	else  # Load a string with fixed order of fields
	  book_a = values.split('|')
	  @@fields.each do |field|
		self[field] = (book_a || []).shift
	  end
    end
	post_initialize
  end

  def add_category(category)
    @category_array << category
	if self[:categories] > ''
	  self[:categories] += '; ' + category
	else
	  self[:categories] = category
    end
  end

  def flatten_categories
    self[:categories] = self[:categories].to_a.join(', ')
	self[:reading_time] = self[:reading_time].to_f
	return self
  end

def post_initialize
    if self[:author] =~ /(.*);/
	  self[:author] = $1
	end
	if self[:author] =~ /(.*[a-z])\.$/
	  self[:author] = $1
	end
    self[:blurb].chomp!
    blurb = self[:blurb]
	if blurb =~ /\. +For ((grades [Kk0-9\-]*)|(junior.*)|(senior.*)|(preschool.*)|(kindergarten.*)).$/
	   self[:target_age] = $1
	end
	if blurb =~ /\. ([^\.]*(Award|Prize)[^\.]*)\. ([0-9]{4})\./ #Prizes, Awards
       self[:awards] = $1
    end
    if blurb =~ /\. +([0-9]{4})\./
      self[:year] = $1
    end
    if blurb =~ /commercial audiobook/i
      self[:product] = "commercial audiobook"
    end
	self[:language] = 'English'
	if blurb =~ /\. ([A-Z]\w+) language\./
	  self[:language] = $1
	end
	self[:categories].sub!(/A production of.*\.,? */, '') # This sometimes pollutes the categories string
	@category_array = (self[:categories] || '').split('; ')
	@category_array.each do |category|
		if category =~ /(.*) language/i
		  self[:language] = $1
		end
	end
    self[:date_added] = Date::today
end

  def get_rating # look up rating on Goodreads or other service
	return if (self[:goodreads_title] || '').downcase == 'ignore'
	rating = goodreadsRating(self) || {}
    self[:stars_date] = Date::today  # set date we last checked ratings
	if rating[:match]  # no match, don't change
		self[:stars] = rating[:stars]
		self[:ratings] = rating[:count]
		self[:goodreads_title] = rating[:goodreads_title]
		self[:goodreads_author] = rating[:goodreads_author]
	end
	if rating[:goodreads_title] == 'ignore'
	    self[:goodreads_title] = 'ignore'
	end
	if rating[:match] == false
	    self[:goodreads_title] = 'no match xxx'
	end
  end

end

# configure selenium for chrome
def init_chromium_driver
	options = Selenium::WebDriver::Chrome::Options.new
	options.add_argument('--ignore-certificate-errors')
	options.add_argument('--disable-popup-blocking')
	options.add_argument('--disable-translate')
	options.add_argument('--headless')
	options.add_argument('--disable-gpu')
	return Selenium::WebDriver.for :chrome, options: options
end

# test_raw_entries = ["\n\n\n\"A convention of delegates\": the creation of the Constitution DB26864\nHauptly, Denis J. \nReading time: 3 hours, 12 minutes. \n\nRead by Ronald B Meyer. \n\n\nGovernment and Politics\n\nDescribes the creation of the U.S. Constitution through anecdotes and profiles of Founding Fathers Washington, Madison, Hamilton, Franklin, Jay, Randolph, Paterson, and Sherman. For grades 5-8.\nDownload \"A convention of delegates\": the creation of the Constitution \n\n\n\n",
# "\n\n\n\"A nation is dying\": Afghanistan under the Soviets, 1979-87 DB30498\nLaber, Jeri; Rubin, Barnett R. \nReading time: 7 hours, 43 minutes. \n\nRead by Ken Kliban. \n\n\nWorld History and Affairs\n\nMore than five million people have fled to Iran and Pakistan since the beginning of the Soviet-Afghan war. Using interviews with hundreds of these refugees, the authors paint a picture of a staggering number of human rights violations against the citizens of Afghanistan. Violence. 2015.\nDownload \"A nation is dying\": Afghanistan under the Soviets, 1979-87 \n\n\n\n",
# "\n\n\n\"A revolting transaction\" DB21578\nConrad, Barnaby. \nReading time: 7 hours, 4 minutes. \n\nRead by Robert Stattel. \n\n\nTrue Crime\n\nUnearthing some mysterious letters in his mother's trunks, the author becomes immersed in a century-old murder investigation. The victim was his great-grandmother, a wealthy Denver widow who was mailed some poisoned whiskey from the East. A true crime study with a re-creation of the Victorian era.\nDownload \"A revolting transaction\"\n\n\n\n",
# "\n\n\nA, my name is Ami DB29086\nMazer, Norma Fox. \nReading time: 3 hours, 19 minutes. \n\nRead by Mitzi Friedlander. \n\n\nFriendship Fiction\n\nSeventh-graders Ami and Mia have been best friends for four years. They talk for hours on the telephone, dress alike, do everything together, and share their dreams. They have even had crushes on the same boy every year since the fourth grade. For grades 6-9.\nDownload A, my name is Ami\n\n\n\n"
# ]

# test_entries = [
# "Seton, Anya.|Avalon|3.86|3,057|Historical Fiction|1965|||15.7|DB50957|Romance and political intrigue in late-tenth-century England. French prince Rumon falls in love with Merewyn, a Cornish girl of peasant and Viking blood. Rumon has also fallen under the spell of powerful Alfrida, who becomes queen of England. Once freed, he learns that Merewyn is in the North American lands colonized by Norsemen. 1965."
# ]
# t = test_entries[0]
# b = Book.new t
# binding.pry
