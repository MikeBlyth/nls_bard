require 'date'
require 'word_wrap'
require 'colorize'

class Book < Hash
  attr_accessor :category_array

  @@fields = %i[author title stars ratings categories year awards target_age reading_time key blurb
                read_by]

  def fields
    @@fields
  end

  def to_s
    post_initialize
    [self[:author], self[:title], self[:stars], self[:ratings], self[:categories], self[:year], self[:awards],
     self[:target_age], self[:reading_time],
     self[:key], self[:blurb], self[:read_by]].join('|')
  end

  def display(screen_output = true)
    post_initialize
    title = self[:title]
    title = title.yellow if screen_output
    s = ["#{title} by #{self[:author]}. #{self[:year]}. #{self[:key]}",
         "#{self[:stars]} stars with #{self[:ratings]} ratings.",
         self[:blurb] + " Reading time #{self[:reading_time]} hours.",
         self[:categories]]
    s << "Read or downloaded #{self[:date_downloaded]}." if self[:has_read]
    s.each { |s| puts WordWrap.ww(s, 90) }
    puts
  end

  def description
    post_initialize
    title = self[:title]
    s = ["#{title}, by #{self[:author]}. Published in #{self[:year]}. ",
         "This book has #{self[:stars]} stars with #{self[:ratings]} ratings. ",
         'Description: ' + self[:blurb] + " The reading time is #{self[:reading_time]} hours.",
         "The NLS number is #{self[:key]}."]
    s.each { |t| puts t }
    puts
  end

  def first_name_first(author = '')
    # if author =~ /([^,]+*), ([^;]+)(; .*)/
    # Try /([^,]+), ([^;]+)(, ((I+)|(Jr\.)))(; .*)?/ matches when Jr. or II but not otherwise. Adding ? makes Jr. get absorbed
  end

  def initialize(values = { title: '', author: '', categories: '', blurb: '', key: '', stars: 0, ratings: 0 })
    return if values.nil?

    if values.is_a? Hash
      values.each { |key, value| self[key] = value }
    else # Load a string with fixed order of fields
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
    self
  end

  def post_initialize
    self[:author] = ::Regexp.last_match(1) if self[:author] =~ /(.*);/
    self[:author] = ::Regexp.last_match(1) if self[:author] =~ /(.*[a-z])\.$/
    self[:blurb].chomp!
    blurb = self[:blurb]
    if blurb =~ /\. +For ((grades [Kk0-9-]*)|(junior.*)|(senior.*)|(preschool.*)|(kindergarten.*)).$/
      self[:target_age] = ::Regexp.last_match(1)
    end
    self[:awards] = ::Regexp.last_match(1) if blurb =~ /\. ([^.]*(Award|Prize)[^.]*)\. ([0-9]{4})\./ # Prizes, Awards
    self[:year] = ::Regexp.last_match(1) if blurb =~ /\. +([0-9]{4})\./
    self[:product] = 'commercial audiobook' if blurb =~ /commercial audiobook/i
    self[:language] = 'English'
    self[:language] = ::Regexp.last_match(1) if blurb =~ /\. ([A-Z]\w+) language\./
    self[:categories].sub!(/A production of.*\.,? */, '') # This sometimes pollutes the categories string
    @category_array = (self[:categories] || '').split('; ')
    @category_array.each do |category|
      self[:language] = ::Regexp.last_match(1) if category =~ /(.*) language/i
    end
    self[:date_added] = Date.today
  end

  def get_rating # look up rating on Goodreads or other service
    return if (self[:goodreads_title] || '').downcase == 'ignore'

    rating = goodreadsRating(self) || {}
    self[:stars_date] = Date.today # set date we last checked ratings
    if rating[:match] # no match, don't change
      self[:stars] = rating[:stars]
      self[:ratings] = rating[:count]
      self[:goodreads_title] = rating[:goodreads_title]
      self[:goodreads_author] = rating[:goodreads_author]
    end
    self[:goodreads_title] = 'ignore' if rating[:goodreads_title] == 'ignore'
    return unless rating[:match] == false

    self[:goodreads_title] = 'no match xxx'
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
  # options.add_argument('--no-sandbox')
  # options.add_argument('--disable-dev-shm-usage')

  Selenium::WebDriver.for :chrome, options:
end


