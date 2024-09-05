FROM ruby:3.3.1

# Install dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    wget \
    gnupg \
    chromium \
    chromium-driver

# Set up your application
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome
RUN mkdir -p /home/chrome/.cache/selenium && chown -R chrome:chrome /home/chrome
USER chrome

# We're not starting the app automatically anymore
#CMD ["/bin/bash"]
CMD ["ruby nls_bard.rb -h"]