require 'pg'

def test_pg_connection
  # Connect to the database
  conn = PG.connect(
    host: 'db', # This should match the service name in docker-compose.yml
    dbname: 'nlsbard',
    user: 'mike',
    password: 'asendulf53'
  )

  # Run a simple query
  result = conn.exec('SELECT version();')

  # Print the result
  puts 'Successfully connected to PostgreSQL.'
  puts "PostgreSQL version: #{result[0]['version']}"

  # Create a test table
  conn.exec('CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(50))')
  puts "Test table created (if it didn't already exist)."

  # Insert a row
  conn.exec('INSERT INTO test_table (name) VALUES ($1)', ['Test Entry'])
  puts 'Inserted a test row.'

  # Query the table
  result = conn.exec('SELECT * FROM test_table')
  puts 'Query result:'
  result.each do |row|
    puts " id: #{row['id']}, name: #{row['name']}"
  end
rescue PG::Error => e
  puts "Error: #{e.message}"
ensure
  conn.close if conn
end

test_pg_connection
