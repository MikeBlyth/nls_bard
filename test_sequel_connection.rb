require 'sequel'

def test_sequel_connection
  # Connect to the database
  @DB = Sequel.connect('postgres://mike:asendulf53@db/nlsbard')

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
