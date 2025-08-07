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

puts "Resetting all author download counts to 0..."
db.run("UPDATE authors SET has_read = 0")

puts "Counting downloads per author..."
author_counts = {}

# Get all downloaded books
db[:books].where(Sequel.~(date_downloaded: nil)).each do |book|
  next if book[:author].nil? || book[:author].strip.empty?
  
  # Split multiple authors
  author_list = book[:author].split(';').map(&:strip).reject(&:empty?)
  
  author_list.each do |author_name|
    parsed = parse_author_name(author_name)
    next if parsed[:last].empty?
    
    key = "#{parsed[:last]}|#{parsed[:first]}|#{parsed[:middle]}"
    author_counts[key] = (author_counts[key] || 0) + 1
  end
end

puts "Updating #{author_counts.size} authors with download counts..."
updated = 0

author_counts.each do |key, count|
  last, first, middle = key.split('|')
  
  rows_updated = db[:authors]
    .where(last_name: last, first_name: first, middle_name: middle)
    .update(has_read: count)
    
  updated += 1 if rows_updated > 0
end

puts "Updated #{updated} authors"

# Show top 10
puts "\nTop 10 Most Downloaded Authors:"
db[:authors].where { has_read > 0 }.order(Sequel.desc(:has_read)).limit(10).each do |author|
  puts "#{author[:first_name]} #{author[:middle_name]} #{author[:last_name]}: #{author[:has_read]} books"
end