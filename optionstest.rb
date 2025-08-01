require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

class OptparseExample

  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.summary = []
    options.download = []
    options.getnew = 0
	options.find_title = ''
	options.outfile = ''
	options.mark = []
    options.verbose = false

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: nls_bard.rb [options]"

      opts.separator ""
      opts.separator "Specific options:"

	  # Search the database for a title
      opts.on("--find TITLE",
              "search database for title (use quotes)") do |title|
        options.find_title << title
	  end	

      # Set an output file
	  opts.on("--output FILE", "file for output") do |outfile|
	    options.outfile = outfile
	  end
	  
      # Cast 'days' argument to Integer.
      opts.on("--getnew N", Integer, "Update DB with books added in past N days") do |n|
        options.getnew = n
      end

      # Summary
      opts.on("--summary x,y,z", Array, "Summaries of a set of books (DBxxxx)") do |list|
        options.summary = list
      end

      # Bookmark
      opts.on("--mark x,y,z", Array, "Bookmark a set of books (DBxxxx)") do |list|
        options.mark = list
      end

      # Download books
      opts.on("--download x,y,z", Array, "Download books") do |list|
        options.download = list
      end

      # Boolean switch. (Verbose doesn't actually do anything currently)
      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options.verbose = v
      end

      # Wishlist remove
      opts.on('--wish_remove TITLE', 'Remove title from wishlist') do |title|
        options.wish_remove = title
      end



      opts.separator ""
      opts.separator "Common options:"

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

    end

    opt_parser.parse!(args)
    options
  end  # parse()

end  # class OptparseExample

options = OptparseExample.parse(ARGV)
# options_input =  ['--mark', 'DB1,DB2,DB3', '--find', 'Winds of War', '--output', 'temp.txt']
# options = OptparseExample.parse(options_input)
#pp options_input 
pp options
#pp options.days, options.books
#options = OptparseExample.parse(['-h'])
#pp options
#pp ARGV