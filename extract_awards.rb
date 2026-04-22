require 'sequel'

DB = Sequel.connect(ENV.fetch('DATABASE_URL'))

WORD = /[\p{Lu}][\p{L}'']*(?:-[\p{Lu}][\p{L}'']*)*(?:\/[\p{Lu}][\p{L}'']*(?:-[\p{Lu}][\p{L}'']*)*)?/
CONN = /of|the|and|for|in|de|la/
# (?!-) prevents matching "Award-winning", "Prize-winning"
TERM = /(?:Awards?|Prizes?)(?!-)/
# No "winner" — capture the award name only, not appended qualifiers
QUAL = /[Ff]inalist|[Hh]onoree|[Nn]ominee/

# (?:the\s+)? after a connector handles "of the Year", "for the Arts", etc.
AWARD_RE = Regexp.new(
  "\\b(#{WORD.source}(?:\\s+(?:#{CONN.source})\\s+(?:the\\s+)?#{WORD.source}|\\s+#{WORD.source})*" \
  "\\s+#{TERM.source}(?:\\s+(?:#{QUAL.source}))?)"
)

# Any Nobel award (Peace, Literature, etc.) only when explicitly awarded in context.
# (?:\s+\S+)? allows for "Nobel Peace Prize", "Nobel Literature Prize", etc.
NOBEL_CTX = /
  \.\s+Nobel(?:\s+\p{Lu}\p{L}*)?\s+Prize(?:\.|\s+(?:in|for)\s+(?:literature|\d{4}))
  |
  \bAwarded\s+Nobel(?:\s+\p{Lu}\p{L}*)?\s+Prize
/xi

updated = 0
DB[:books].where(Sequel.lit("awards IS NOT NULL AND awards != ''")).each do |book|
  text = book[:blurb].to_s.gsub(/Nat'l\b/i, 'National')
  matches = text.scan(AWARD_RE).map(&:first).uniq

  matches.reject! { |m| m =~ /\A(?:By|The|Winner)\b/ }
  matches.select! { |m| m !~ /\bNobel\b/i || text.match?(NOBEL_CTX) }

  if book[:language].to_s.empty? || book[:language] == 'English'
    last_100 = text[-100..].to_s
    matches.select! { |m| last_100.include?(m) }
  end

  awards = matches.empty? ? nil : matches.join('; ')
  DB[:books].where(key: book[:key]).update(awards: awards)
  updated += 1
end

puts "Updated #{updated} books"
