FROM ruby:3.3.1-slim

# Define the frozen Chrome version. This is the single source of truth for a stable environment.
ARG CHROME_VERSION="126.0.6478.126"

# Install essential Linux packages and retry on failure
RUN apt-get update -qq && \
    for i in {1..3}; do \
    apt-get install -y \
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
        # Dependencies for certain gems (like pg)
        libssl-dev \
        libreadline-dev \
        zlib1g-dev \
        # Dependencies for headless Chrome. The Chrome for Testing binary doesn't
        # install these automatically like a .deb package would.
        libnss3 libgconf-2-4 libfontconfig1 libxss1 fonts-liberation \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* && break || sleep 15; \
    done

    # Add Google Chrome repository and install
    RUN \
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
        apt-get update -qq && \
        apt-get install -y google-chrome-stable && \
        # Install matching ChromeDriver using Chrome for Testing API
        apt-get install -y jq && \
        LATEST_VERSION=$(curl -sS "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json" | jq -r '.channels.Stable.version') && \
        wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${LATEST_VERSION}/linux64/chromedriver-linux64.zip" && \
        unzip /tmp/chromedriver.zip -d /tmp/ && \
        mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver && \
        chmod +x /usr/local/bin/chromedriver && \
        rm -rf /tmp/chromedriver* && \
        # Clean up
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*

    
# Create a non-root user for security and set up gem environment
RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome

# Set environment variables for the new user. This ensures gems are installed
# in the user's home directory, avoiding permission issues inside the dev container.
ENV GEM_HOME="/home/chrome/.gems"
ENV PATH="/home/chrome/.gems/bin:$PATH"

# Create necessary directories and set ownership before switching user.
RUN mkdir -p /app/db_dump /home/chrome/.cache/selenium ${GEM_HOME} && \
    chown -R chrome:chrome /app /home/chrome

# Switch to the non-root user for all subsequent commands
USER chrome

# Set up your application
WORKDIR /app

# Copy only Gemfile and Gemfile.lock first to leverage Docker cache.
# The files will be owned by the 'chrome' user because of the USER directive above.
COPY Gemfile Gemfile.lock ./

# Now, as the 'chrome' user, install gems. They will be installed into GEM_HOME.
RUN gem install bundler && \
    for i in {1..3}; do \
    bundle install && break || sleep 15; \
    done

# Now copy the rest of the application code.
COPY . .

# Update rexml as the correct user.
RUN gem update rexml && gem cleanup rexml

# The critical part: Set Bash as the default shell and configure history.
# The user in this Dev Container is `chrome`.
# NOTE: Using `usermod` instead of `chsh` to avoid "Authentication failure" during build.
# We must temporarily switch to the root user to run usermod.
USER root
RUN usermod -s /bin/bash chrome

# Now, switch back to the `chrome` user to create their home directory configuration files.
# This ensures the files are owned by the correct user.
USER chrome
RUN \
    # Create or update a .bashrc file to enable command history
    echo 'HISTSIZE=1000' >> /home/chrome/.bashrc && \
    echo 'HISTFILESIZE=2000' >> /home/chrome/.bashrc && \
    echo 'PROMPT_COMMAND="history -a"' >> /home/chrome/.bashrc
    
CMD ["ruby", "nls_bard.rb", "-h"]
