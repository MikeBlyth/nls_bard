require './nls_bard_sequel.rb' # interface to database

infile = File.open('temp.txt','r')
outfile = File.open('temp2.txt','w')

@DB = BookDatabase.new
@books = @DB.books

infile.each_line do |line|

  if line =~ /(DB[A-Z]?[0-9]{2,})/
    @book = @DB.get_book($1)
	if ! @book.nil?
	   puts @book[:title]
	   @books.filter(key: @book[:key]).update(has_read: true)
	end
  end
  if line =~ /Downloaded: (.*)$/ and @book
    date = $1
	puts "--#{date}"
	@books.filter(key: @book[:key]).update(date_downloaded: date)
  end
end