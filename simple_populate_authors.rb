require 'sequel'
require 'dotenv/load'
require_relative 'name_parse'

def parse_author_name(name)
  return {last: '', first: '', middle: ''} if name.nil? || name.strip.empty?
  
  name = name.strip
  
  # Handle corporate/organizational authors
  if name.include?('(') || name.include?('Society') || name.include?('Association') || 
     name.include?('Institute') || name.include?('Organization') || name.include?('Inc.') ||
     name.include?('Corp.') || name.include?('Company') || name.include?('Press')
    return {last: name[0..19], first: '', middle: ''}
  end
  
  parsed = name_parse(name)
  {
    last: (parsed[:last] || '')[0..19],
    first: (parsed[:first] || '')[0..19], 
    middle: (parsed[:middle] || '')[0..19]
  }
end

# Connect to database
user = ENV.fetch('POSTGRES_USER', 'mike')
password = ENV.fetch('POSTGRES_PASSWORD')
host = ENV.fetch('POSTGRES_HOST', 'db')
db_name = ENV.fetch('POSTGRES_DB', 'nlsbard')

db = Sequel.connect("postgres://#{user}:#{password}@#{host}/#{db_name}")

puts "Populating authors table..."
authors_added = 0

db[:books].each do |book|
  next if book[:author].nil? || book[:author].strip.empty?
  
  # Split multiple authors by semicolon
  author_list = book[:author].split(';').map(&:strip).reject(&:empty?)
  
  author_list.each do |author_name|
    parsed = parse_author_name(author_name)
    next if parsed[:last].empty?
    
    begin
      db[:authors].insert(
        last_name: parsed[:last],
        first_name: parsed[:first],
        middle_name: parsed[:middle]
      )
      authors_added += 1
      puts "Added: #{parsed[:first]} #{parsed[:middle]} #{parsed[:last]}" if authors_added % 100 == 0
    rescue Sequel::UniqueConstraintViolation
      # Already exists, skip
    end
  end
end

puts "Added #{authors_added} unique authors"
puts "Total authors in table: #{db[:authors].count}"