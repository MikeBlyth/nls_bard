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

  # Initializes a Book object from a hash of attributes.
  def initialize(values = {})
    # Directly assign hash values. The default empty hash prevents errors.
    values.each { |key, value| self[key] = value }
    post_initialize
  end

  # Creates a new Book instance by parsing a pipe-delimited string.
  def self.from_string(pipe_string)
    return new if pipe_string.nil?

    book_hash = {}
    book_a = pipe_string.split('|')
    @@fields.each do |field|
      book_hash[field] = (book_a || []).shift
    end
    new(book_hash)
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

  private

  # This method is called after initialization to parse and clean up attributes.
  def post_initialize
    # Ensure essential keys have default values to prevent nil errors downstream.
    self[:key] ||= ''
    self[:author] ||= ''
    self[:blurb] ||= ''
    self[:categories] ||= ''

    self[:key].strip! # Ensure the book's key has no leading/trailing whitespace.

    clean_author_name
    parse_attributes_from_blurb
    parse_categories
    self[:date_added] ||= Date.today
  end

  def clean_author_name
    # Remove trailing semicolons or periods from author names.
    self[:author] = ::Regexp.last_match(1) if self[:author] =~ /(.*);/
    self[:author] = ::Regexp.last_match(1) if self[:author] =~ /(.*[a-z])\.$/
  end

  def parse_attributes_from_blurb
    blurb = self[:blurb].chomp
    # These regexes extract structured data from the unstructured blurb text.
    if blurb =~ /\. +For ((grades [Kk0-9-]*)|(junior.*)|(senior.*)|(preschool.*)|(kindergarten.*)).$/
      self[:target_age] ||= ::Regexp.last_match(1)
    end
    self[:awards] ||= ::Regexp.last_match(1) if blurb =~ /\. ([^.]*(Award|Prize)[^.]*)\. ([0-9]{4})\./
    self[:year] ||= ::Regexp.last_match(1) if blurb =~ /\. +([0-9]{4})\./
    self[:product] ||= 'commercial audiobook' if blurb =~ /commercial audiobook/i
    self[:language] ||= 'English'
    self[:language] = ::Regexp.last_match(1) if blurb =~ /\. ([A-Z]\w+) language\./
  end

  def parse_categories
    # Clean up the categories string and create a clean array of category names.
    self[:categories].sub!(/A production of.*\.,? */, '') # This sometimes pollutes the categories string
    # The BARD site uses commas to separate categories. Split by comma, then strip whitespace from each item.
    # The reject(&:empty?) handles cases of trailing commas or empty strings.
    @category_array = (self[:categories] || '').split(',').map(&:strip).reject(&:empty?)
    # Also extract language if it's listed as a category.
    @category_array.each do |category|
      self[:language] = ::Regexp.last_match(1) if category =~ /(.*) language/i
    end
  end
end
