require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
require_relative 'nls_bard_sequel'
require_relative 'nls_book_class'

configure do
  set :port, 4567
  set :bind, '0.0.0.0'
  set :views, File.join(__dir__, 'views')
end

DB_WEB = BookDatabase.new

# --- Pages ---

get '/' do
  erb :index
end

get '/wishlist' do
  erb :wishlist
end

# --- Search ---

post '/search' do
  query  = params[:query].to_s.strip
  author = params[:author].to_s.strip
  mode   = params[:mode] || 'find'
  lang   = params[:language] == 'all' ? nil : (params[:language].presence || 'English')
  limit  = (params[:limit] || '25').to_i.clamp(1, 500)
  sort_relevance = params[:sort] == 'relevance'
  media  = params[:media_type] == 'all' ? nil : (params[:media_type].presence || 'DB')

  @books = if query.empty? && author.empty?
             []
           else
             case mode
             when 'full'
               DB_WEB.get_by_full_text(query, limit: limit, language: lang, sort_by_relevance: sort_relevance, media_type: media).to_a
             when 'fuzzy'
               DB_WEB.get_by_hash_fuzzy({ title: query, author: author, language: lang, media_type: media }).limit(limit).to_a
             else
               DB_WEB.get_by_hash({ title: query, author: author, blurb: '', language: lang, media_type: media }).limit(limit).to_a
             end
           end

  unless @books.empty?
    keys = @books.map { |b| b[:key] }
    cats_by_key = DB_WEB.DB[:cat_book]
                        .join(:cats, category: :category)
                        .where(book: keys)
                        .select(:book, Sequel[:cats][:category])
                        .all
                        .group_by { |r| r[:book] }
                        .transform_values { |rows| rows.map { |r| r[:category] }.uniq }
    @books = @books.map { |b| b.merge(categories: cats_by_key[b[:key]] || []) }
  end

  erb :search_results, layout: false
end

# --- Book detail (modal content) ---

get '/book/:key' do
  @book = DB_WEB.get_book(params[:key])
  halt 404, 'Book not found' unless @book
  @categories = DB_WEB.DB[:cat_book]
                      .join(:cats, category: :category)
                      .where(book: params[:key])
                      .select(Sequel[:cats][:category])
                      .map { |r| r[:category] }
                      .uniq
  erb :book_detail, layout: false
end

# --- Download ---

DOWNLOAD_STATUS = {}

post '/download/:key' do
  key = params[:key].upcase
  download_dir = ENV.fetch('CONTAINER_DOWNLOAD_PATH', '/app/downloads')
  DOWNLOAD_STATUS[key] = { status: :starting }

  Thread.new do
    existing_temps = Dir.glob(File.join(download_dir, '*.crdownload')) +
                     Dir.glob(File.join(download_dir, '.com.google.Chrome.*'), File::FNM_DOTMATCH)
    pid = spawn("ruby /app/nls_bard.rb -d #{key}")
    sleep 4
    loop do
      break if Process.waitpid(pid, Process::WNOHANG)
      files = (Dir.glob(File.join(download_dir, '*.crdownload')) +
               Dir.glob(File.join(download_dir, '.com.google.Chrome.*'), File::FNM_DOTMATCH)) - existing_temps
      kb = files.sum { |f| File.size(f) rescue 0 } / 1024
      DOWNLOAD_STATUS[key] = { status: :downloading, kb: kb }
      sleep 2
    end
    Process.waitpid(pid)
    DOWNLOAD_STATUS[key] = { status: :complete }
  end

  content_type :html
  download_status_html(key)
end

get '/download/:key/status' do
  key = params[:key].upcase
  content_type :html
  info = DOWNLOAD_STATUS[key] || { status: :unknown }
  if info[:status] == :complete
    DOWNLOAD_STATUS.delete(key)
    %(<span class="text-green-400">✓ Download complete: #{h(key)}</span>)
  else
    download_status_html(key)
  end
end

# --- Wishlist CRUD ---

get '/wishlist/items' do
  @items = wishlist_with_matches
  erb :wishlist_items, layout: false
end

post '/wishlist' do
  title  = params[:title].to_s.strip
  author = params[:author].to_s.strip
  if title.empty? || author.empty?
    halt 422, '<p class="text-red-400">Title and author are required.</p>'
  end
  DB_WEB.insert_wish({ title: title, author: author })
  @items = wishlist_with_matches
  erb :wishlist_items, layout: false
end

delete '/wishlist/:id' do
  DB_WEB.DB[:wishlist].where(id: params[:id].to_i).delete
  ''
end

post '/wishlist/check' do
  begin
    DB_WEB.check_for_wishlist_matches
  rescue => e
    STDERR.puts "Wishlist check error: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
  end
  @items = wishlist_with_matches
  erb :wishlist_items, layout: false
end

# --- Helpers ---

helpers do
  def wishlist_with_matches
    DB_WEB.DB.fetch(<<~SQL).all
      SELECT w.id, w.title AS wish_title, w.author AS wish_author,
             w.key, b.title AS book_title, b.author AS book_author,
             b.stars, b.key AS book_key
      FROM wishlist w
      LEFT JOIN books b ON b.key = w.key
      WHERE w.date_downloaded IS NULL
      ORDER BY (w.key IS NOT NULL) DESC, w.title
    SQL
  end

  def catalog_count
    @catalog_count ||= DB_WEB.books.count
  end

  def star_color(stars)
    return 'text-slate-500' if stars.nil?
    stars >= 4.0 ? 'text-green-400' : stars >= 3.5 ? 'text-amber-400' : 'text-slate-400'
  end

  def format_stars(stars)
    stars ? format('%.1f ⭐', stars) : 'No rating'
  end

  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end

  def download_status_html(key)
    info = DOWNLOAD_STATUS[key] || { status: :starting }
    label = case info[:status]
            when :downloading then "⬇ #{h(key)} — #{info[:kb]} KB"
            when :complete    then "✓ #{h(key)} complete"
            else                   "⬇ Starting #{h(key)}…"
            end
    color = info[:status] == :complete ? 'text-green-400' : 'text-yellow-400'
    %(<span class="#{color}" hx-get="/download/#{h(key)}/status" hx-trigger="every 2s" hx-swap="outerHTML">#{label}</span>)
  end
end

class String
  def presence
    empty? ? nil : self
  end
end
