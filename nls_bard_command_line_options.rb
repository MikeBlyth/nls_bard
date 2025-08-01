require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

class Optparse
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.summary = []
    options.download = []
    options.getnew = 0
    options.title = ''
    options.author = ''
    options.blurb = ''
    options.find = false
    options.marked = false
    options.output = ''
    options.mark = []
    options.unmark = []
    options.wish = false
    options.wish_remove = ''
    options.key = ''
    options.debug = false
    options.backup = false
    options.update_ratings = false
    options.manual_update = false

    options.verbose = false

    opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage: nls_bard.rb [options]'

      opts.separator ''
      opts.separator 'Actions:'

      # Update with the latest books
      opts.on('-g', '--getnew N', Integer, 'Update DB with books added in past N days') do |n|
        options.getnew = n
      end

      # Find
      opts.on('-f', '--find', 'Find in database (use title, author, and/or blurb') do |f|
        options.find = true
      end

      # Summary
      #      opts.on("--summary x,y,z", Array, "Summaries of a set of books (DBxxxx)") do |list|
      #        options.summary = list
      #      end

      # Bookmark
      opts.on('-m', '--mark x,y,z', Array, 'Bookmark a set of books (DBxxxx)') do |list|
        options.mark = list
      end

      # Remove Bookmark
      opts.on('--unmark x,y,z', Array, 'Remove bookmarks from a set of books (DBxxxx)') do |list|
        options.unmark = list
      end

      # List/return Bookmarked
      opts.on('--marked', 'Select marked books') do |v|
        options.marked = true
      end

      # Wishlist
      opts.on('-w', '--wish', 'Add to wishlist (use --author, --title), or print wishlist') do |v|
        options.wish = true
      end

      # Wishlist delete
      opts.on('--wish_remove TITLE', 'Remove title from wishlist') do |title|
        options.wish_remove = title
      end

      # Download books
      opts.on('-d', '--download x,y,z', Array, 'Download books by key') do |list|
        options.download = list
      end

      # Debug
      opts.on('--[no-]debug', 'Debug (debug gem must be required, and debugger statements included)') do |p|
        options.debug = p
      end

      # Update database stars and number of ratings
      opts.on('-u', '--update', 'Update ratings') do |p|
        options.update_ratings = true
      end

      # Use manual updating
      opts.on('-m', '--manual_update', 'Get user input for non-matches') do |p|
        options.manual_update = true
      end

      # backup
      opts.on('-b', '--backup',
              'backup database to zip file') do |key|
        options.backup = true
      end

      opts.separator ''
      opts.separator 'Filters:'

      #  title
      opts.on('-t',	'--title TITLE',
              'search database for title (use quotes)') do |title|
        options.title << title
      end

      # author
      opts.on('-a', '--author AUTHOR',
              'search database for author (use quotes)') do |author|
        options.author << author
      end

      # blurb
      opts.on('-b', '--blurb CONTAINING',
              'search database for blurb containing (use quotes)') do |contains|
        options.blurb << contains
      end

      # key
      opts.on('-k', '--key KEY',
              'specify book key (e.g. DB60197)') do |key|
        options.key << key
      end

      opts.separator ''
      opts.separator 'Runtime options:'

      # Verbose
      # Set an output file
      opts.on('-o', '--output FILE', 'file for output') do |output|
        options.output = output
      end

      opts.on('-v', '--[no-]verbose', 'Long descriptions') do |v|
        options.verbose = v
      end

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end # parse()
end # class OptparseExample

# options = Optparse.parse(ARGV)
# options_input =  ['--mark', 'DB1,DB2,DB3', '--find', 'Winds of War', '--output', 'temp.txt']
# options = OptparseExample.parse(options_input)
# pp options_input
# pp options
# pp options.days, options.books
# options = OptparseExample.parse(['-h'])
# pp options
# pp options
