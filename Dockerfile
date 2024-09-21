FROM ruby:3.3.1-slim

# Install essential Linux packages and retry on failure
RUN apt-get update -qq && \
    for i in {1..3}; do \
        apt-get install -y \
            build-essential \
            libpq-dev \
            postgresql-client \
            wget \
            gnupg \
            chromium \
            chromium-driver && break || sleep 15; \
    done

# Install dependencies required for certain gems
RUN apt-get install -y \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev

# Set up your application
WORKDIR /app
COPY Gemfile Gemfile.lock ./

# Install bundler and gems with retry mechanism
RUN gem install bundler && \
    for i in {1..3}; do \
        bundle config set --local without 'development test' && \
        bundle install && break || sleep 15; \
    done

COPY . .

RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome
RUN mkdir -p /app/db_dump && chown -R $USER:$USER /app/db_dump
RUN mkdir -p /home/chrome/.cache/selenium && chown -R chrome:chrome /home/chrome
USER chrome

CMD ["ruby", "nls_bard.rb", "-h"]