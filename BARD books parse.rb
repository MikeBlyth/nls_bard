# Extract data from the list of books at BARD
# # https://nlsbard.loc.gov
#

class Massager
  attr_accessor :output_buf, :line, :info, :filters, :all_categories, :selected_categories

  def initialize
    @output_buf = ''
    @filters = { categories_reject: Set[:Romance, :"Fantasy Fiction", :"Science and Technology", :"Stage and Screen", :"Mystery and Detective Stories", :"True Crime",
                                        :"Science Fiction", :"Medical Fiction", :"Historical romance fiction", :"Suspense Fiction", :"Psychology and Self-Help", :Computers, :"Romantic suspense fiction", :"Spanish Language", :"Diet and Nutrition", :"Occult and the Paranormal", :"Religious Fiction", :"Western Stories", :"Sports and Recreation", :Gardening, :"Supernatural and Horror Fiction"
      ] }
    @all_categories = Set[]
    @selected_categories = Set[]
    init_info
    @line = ''
    @linenumber = 0
    @was_blank = false
    @line = ''
    filename = 'newBooksTest.txt'
    filebase = File.basename(filename, '.txt')
    @infile = File.open(filename, 'r')
    @outfile = File.open("#{filebase}_output.txt", 'w+')
    # @is_blank = true
  end

  def init_info
    @info = { title: '', categories: Set[], cat_sw: false, entry_line: 0,
              section: 'xx', blurb: '' }
  end

  # True = accept this entry, false = reject
  def accept_entry?
    cats = @info[:categories]
    reject = @filters[:categories_reject]
    accept = cats.disjoint? reject # no rejected  categories
    accept = false if @info[:title] == ''
    accept
  end

  # Is a line blank
  def blank?
    (@line.strip == '')
  end

  def append_with_space(object_to_append)
    @output_buf += ' ' if @output_buf != ''
    @output_buf += object_to_append
  end

  def new_entry?
    matches = (@line =~ /(.*) (DB[A-Z0-9]+)/)
    !matches.nil?
  end

  def end_of_entry?
    matches = (@line =~ /^Download /)
    !matches.nil?
  end

  def process_line
    @info[:entry_line] += 1
    puts "<#{@info[:entry_line]}:#{@info[:section]}> | " + @line
    # sleep(0.005)

    # Start new entry
    if @line =~ /(.*) (DB[A-Z0-9]+)/
      puts
      @info[:title] = ::Regexp.last_match(1)
      @info[:db] = ::Regexp.last_match(2)
      @info[:type] = :book
      @info[:section] = ':author' # because the next line should be author
      # puts "New: section=#{@info[:section]}"
    end
    # puts "section=#{@info[:section]}, @line.length = #{@line.length}"
    if (@info[:section] == :categories && @line.length > 60) || (@line.length > 100)
      # puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
      @info[:section] = :blurb # this just HAS to be the blurb/description
      @output_buf = ''
      # puts "Blurb: section=#{@info[:section]}"
    end
    # puts "Before case: section=#{@info[:section]}"

    if @line =~ /(.*)\. Reading time/
      @info[:author] = ::Regexp.last_match(1)
    elsif @line =~ /Read by (.*)/
      @info[:read_by] = ::Regexp.last_match(1)
      @info[:section] = :categories
    elsif @info[:section] == :categories
      #       puts "^^"+@info[:categories].join
      if blank? && @info[:categories].count.positive? # blank ends list of categories
        # this happens if there are not categories, i.e. in periodicals
        @info[:section] = :blurb
        @output_buf = ''
      elsif @line > '' and (@line =~ /Download/).nil?
        @info[:categories] << @line.to_sym
        @all_categories << @line.to_sym
        #     puts "Added #{@line} so categories = #{@info[:categories]}"
      end
    end

    append_with_space(@line.lstrip) unless @line =~ /^Download/ # This merges lines ignoring leading whitespace
    #    puts "&" + @output_buf
    #   # Requires writing _before_ processing
    # put any processing here,
    #
    @was_blank = blank?
  end

  def process_before_output(buffer)
    @info[:prizes] = ::Regexp.last_match(1) if buffer =~ /\. ([^.]*(Award|Prize)[^.]*)\. ([0-9]{4})\./ # Prizes, Awards
    @info[:year] = ::Regexp.last_match(1) if buffer =~ /\. ([0-9]{4})\./
    @info[:product] = 'commercial audiobook' if buffer =~ /commercial audiobook/i
    category_string = @info[:categories].to_a.join(', ')
    [@info[:author], @info[:title], @info[:date], category_string, @info[:year], @info[:prizes], @output_buf].join('|')
  end

  def do_output
    #    puts "do_output #{@info}"
    if accept_entry?
      @output_buf = process_before_output(@output_buf)
      @outfile.puts @output_buf
      @selected_categories += @info[:categories] # Add to list of selected categories
    end
    @output_buf = ''
    @info[:section] = ''
    init_info
  end

  def closing_tasks
    do_output # flush last entry
    puts "\nAll categories in input file"
    @all_categories.to_a.sort.each { |x| puts x }
    puts "\nAll categories in selected entries"
    @selected_categories.to_a.sort.each { |x| puts x }
  end

  def process_lines
    @infile.each_line do |input_line|
      @linenumber += 1
      @line = input_line.chomp.force_encoding('UTF-8')
      puts " #{@linenumber}|#{@within_entry}|" + @line
      if new_entry?
        #  puts "this is a new entry, line=#{@line}"
        do_output # before processing anything
        @within_entry = true
      end
      if end_of_entry?
        @within_entry = false
        @info[:entry_line] = 0
      elsif @within_entry
        process_line
      end
      return if @info[:entry_line] > 25 # rubocop:disable Lint/NonLocalExitFromIterator
    end
  end

  def main
    process_lines
    closing_tasks
    @outfile.close
    #		puts "Finished"
  end

  # Test
  def testinit
    # Do something to initialize testing
  end

  def test
    testinit
    # Do whatever tests
  end
end
# Main section

m = Massager.new
m.main
