require 'sequel'
require 'dotenv/load'

def test_sequel_connection
  # Connect to the database
  user = ENV.fetch('POSTGRES_USER', 'mike')
  password = ENV.fetch('POSTGRES_PASSWORD')
  host = ENV.fetch('POSTGRES_HOST', 'db')
  db_name = ENV.fetch('POSTGRES_DB', 'nlsbard')

  @DB = Sequel.connect("postgres://#{user}:#{password}@#{host}/#{db_name}")

  # Run a simple query
  version = @DB['SELECT version()'].first[:version]

  puts 'Successfully connected to PostgreSQL.'
  puts "PostgreSQL version: #{version}"

  # Create a test table
  @DB.create_table? :test_table do
    primary_key :id
    String :name
  end
  puts "Test table created (if it didn't already exist)."

  # Insert a row
  @DB[:test_table].insert(name: 'Test Entry')
  puts 'Inserted a test row.'

  # Query the table
  puts 'Query result:'
  @DB[:test_table].each do |row|
    puts " id: #{row[:id]}, name: #{row[:name]}"
  end
rescue Sequel::Error => e
  puts "Error: #{e.message}"
ensure
  @DB.disconnect if defined?(DB)
end

test_sequel_connection
