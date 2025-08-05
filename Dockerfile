FROM ruby:3.3.1-slim

# Define the frozen Chrome version. This is the single source of truth for a stable environment.
ARG CHROME_VERSION="126.0.6478.126"
# Add UID/GID arguments. These are passed from docker-compose.yml to ensure
# the container user's permissions match the host user's, avoiding file
# permission errors on mounted volumes.
ARG UID=1000
ARG GID=1000

# Install essential Linux packages, Chrome, and ChromeDriver in a single layer to optimize build time and image size.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        postgresql-client \
        wget \
        gnupg \
        curl \
        unzip \
        jq \
        bash \
        bash-completion \
        readline-common \
        libreadline-dev \
        less \
        libssl-dev \
        zlib1g-dev \
        libnss3 libgconf-2-4 libfontconfig1 libxss1 fonts-liberation && \
    # Add Google Chrome repository and install
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    # Install matching ChromeDriver using Chrome for Testing API
    LATEST_VERSION=$(curl -sS "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json" | jq -r '.channels.Stable.version') && \
    wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${LATEST_VERSION}/linux64/chromedriver-linux64.zip" && \
    unzip /tmp/chromedriver.zip -d /tmp/ && \
    mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver && \
    chmod +x /usr/local/bin/chromedriver && \
    rm -rf /tmp/chromedriver* && \
    # Clean up apt caches to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user 'chrome' with the host's UID/GID and set its shell.
# This is the key to solving file permission issues with mounted volumes.
# The -o flag allows for a non-unique UID, and -m creates the home directory.
RUN groupadd -g ${GID} -o chrome && \
    useradd -u ${UID} -g ${GID} -o -m -s /bin/bash chrome

# Set environment variables for the new user. This ensures gems are installed
# in the user's home directory, avoiding permission issues inside the dev container.
ENV GEM_HOME="/home/chrome/.gems"
ENV PATH="/home/chrome/.gems/bin:$PATH"

# Create necessary directories and set ownership before switching user.
# The user 'chrome' now exists, so this will succeed.
RUN mkdir -p /app/db_dump /app/output /home/chrome/.cache/selenium ${GEM_HOME} && \
    chown -R chrome:chrome /app /home/chrome

# Switch to the non-root user for all subsequent commands
USER chrome

WORKDIR /app

# Copy only Gemfile and Gemfile.lock first to leverage Docker cache.
# Use --chown to set ownership during the copy.
COPY --chown=chrome:chrome Gemfile Gemfile.lock ./

# Now, as the 'chrome' user, install gems. They will be installed into GEM_HOME.
RUN gem install bundler && \
    for i in {1..3}; do \
    bundle install && break || sleep 15; \
    done

COPY --chown=chrome:chrome . .

RUN gem update rexml && gem cleanup rexml

# The user's shell is already set to /bin/bash during creation.
# The .bashrc setup is still useful for interactive sessions.
RUN \
    # Create or update a .bashrc file to enable command history
    echo 'HISTSIZE=1000' >> /home/chrome/.bashrc && \
    echo 'HISTFILESIZE=2000' >> /home/chrome/.bashrc && \
    echo 'PROMPT_COMMAND="history -a"' >> /home/chrome/.bashrc
    
CMD ["ruby", "nls_bard.rb", "-h"]
