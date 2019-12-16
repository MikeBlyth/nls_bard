require 'pg'
require 'pry'

conn = PG.connect(:dbname => 'nlsbard', :user=>'mike', :password=>'asendulf53')
res = conn.exec('select key, title from books')

res.each do |row|
    puts row
end
binding.pry

