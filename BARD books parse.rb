# Extract data from the list of books at BARD 
# https://nlsbard.loc.gov
#
require 'set'

class Massager
  attr_accessor :output_buf, :line, :info, :filters, :all_categories, :selected_categories

	def initialize
#		puts "Starting"
		@output_buf = ''
    @filters = {:categories_reject=>Set[:Romance, :"Fantasy Fiction", :"Science and Technology", :"Stage and Screen", :"Mystery and Detective Stories", :"True Crime", 
    :"Science Fiction", :"Medical Fiction", :"Historical romance fiction", :"Suspense Fiction", :"Psychology and Self-Help", :Computers, :"Romantic suspense fiction", :"Spanish Language", :"Diet and Nutrition", :"Occult and the Paranormal", :"Religious Fiction", :"Western Stories", :"Sports and Recreation", :Gardening, :"Supernatural and Horror Fiction"
      ]}
    @all_categories = Set[]
    @selected_categories = Set[]
    init_info
		@line = ''
		@linenumber = 0
    @was_blank = false
		@line = ''
  #  filename = 'test2.txt'
	#	filename='booklist.txt'
  	filename='newBooksTest.txt'
		filebase = File.basename(filename,'.txt')
		@infile = File.open(filename, "r")
		@outfile = File.open(filebase+"_output.txt",'w+')
		@is_blank = true
	end
	
  def init_info
    @info = {:title=>'', :categories=> Set[], :cat_sw=>false, :entry_line=>0,
             :section=> 'xx', :blurb => '' }
  end

  def accept_entry? # True = accept this entry, false = reject
    cats = @info[:categories]
    title = @info[:title]
    reject = @filters[:categories_reject]
    accept = true
    accept = cats.disjoint? reject # no rejected  categories
    accept = false if @info[:title] == ''
#    puts "accept=#{accept} - cats=#{cats}, reject=#{reject}, title=#{title}"
#    puts "disjoint=#{cats.disjoint? reject}"
#    gets
    return accept
  end

  def is_blank # blank line
	#	return @line =~ /Download #{@info[:title]}/
    return (@line.strip == "")  
  end

  def append_with_space (object_to_append)
    if @output_buf != '' then
      @output_buf += ' '
    end
    @output_buf += object_to_append
  end

  def is_new_entry?
    matches = (@line =~ /(.*) (DB[A-Z0-9]+)/)
    return(not matches.nil?)
  end

  def is_end_of_entry?
    matches = (@line =~ /^Download /)
    return(not matches.nil?)
  end

	def process_line
#    @output_buf = @line  # No processing, just outputs the line as read; delete if output_buf will be constructed
    @info[:entry_line] += 1
    puts "<#{@info[:entry_line]}:#{@info[:section]}> | " + @line
    #sleep(0.005)

    if @line =~ /(.*) (DB[A-Z0-9]+)/  then # Start new entry
      puts
      @info[:title] = $1
      @info[:db] = $2
      @info[:type] = :book
      @info[:section] = ':author' # because the next line should be author
    #puts "New: section=#{@info[:section]}"
    end
    # puts "section=#{@info[:section]}, @line.length = #{@line.length}"
    if (@info[:section] == :categories && @line.length > 60) || (@line.length > 100) then 
      #puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
      @info[:section] = :blurb  # this just HAS to be the blurb/description
      @output_buf = ''
    #puts "Blurb: section=#{@info[:section]}"

    end
    #puts "Before case: section=#{@info[:section]}"
    case
      when @line =~ /(.*)\. Reading time/
        @info[:author] = $1
      when @line =~ /Read by (.*)/
        @info[:read_by] = $1
        @info[:section] = :categories
      when @info[:section] == :categories 
 #       puts "^^"+@info[:categories].join
        if (is_blank && @info[:categories].count > 0) then # blank ends list of categories
             # this happens if there are not categories, i.e. in periodicals
              @info[:section] = :blurb
              @output_buf = ''
        else
          if @line > '' and (@line =~ /Download/).nil?
            @info[:categories] << @line.to_sym
            @all_categories << @line.to_sym
#            puts "Added #{@line} so categories = #{@info[:categories]}"
          end
        end
    end # case
		append_with_space(@line.lstrip) unless @line =~ /^Download/ # This merges lines ignoring leading whitespace
#    puts "&" + @output_buf
#                                   # Requires writing _before_ processing
    # put any processing here, 
#
    @was_blank = is_blank
	end
	
  def process_before_output(buffer)
    if buffer =~ /\. ([^\.]*(Award|Prize)[^\.]*)\. ([0-9]{4})\./ #Prizes, Awards
       @info[:prizes] = $1
    end
    if buffer =~ /\. ([0-9]{4})\./
      @info[:year] = $1
    end
    if buffer =~ /commercial audiobook/i 
      @info[:product] = "commercial audiobook"
    end 
    category_string = @info[:categories].to_a.join(', ') 
    buffer = [@info[:author], @info[:title], @info[:date], category_string, @info[:year], @info[:prizes], @output_buf].join("|")
    return buffer 
  end

	def do_output
#    puts "do_output #{@info}"
    if accept_entry? 
      @output_buf = process_before_output(@output_buf)
      @outfile.puts @output_buf
      @selected_categories += @info[:categories] # Add to list of selected categories
    end
  #    puts '>>' + @output_buf
    @output_buf = '' 
    @info[:section] = ''
    init_info
	end

  def closing_tasks
    do_output # flush last entry
    puts "\nAll categories in input file"
    @all_categories.to_a.sort.each {|x| puts x}
    puts "\nAll categories in selected entries"
    @selected_categories.to_a.sort.each {|x| puts x}
  end

	def process_lines
		@infile.each_line { |input_line|
	    @linenumber = @linenumber + 1
		  @line = input_line.chomp.force_encoding("UTF-8")
#      puts '<EOF>' if @infile.eof?
      puts " #{@linenumber}|#{@within_entry}|" + @line
      if is_new_entry? then
      #  puts "this is a new entry, line=#{@line}"
        do_output # before processing anything
        @within_entry = true
      end
      if is_end_of_entry? then
        @within_entry = false
        @info[:entry_line] = 0
      else 
        if @within_entry then
          process_line  
        end
      end  
      return if @info[:entry_line] > 25
    }
		 
	end # 

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
end # class
# Main section

m = Massager.new
m.main

