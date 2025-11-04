# 1. Base Image
# Using a slim image keeps the final size smaller
FROM ruby:3.2.5-slim

# 2. System Dependencies and Build Tools
# Install system libraries needed for common gems (mysql2, postgresql-client, etc.)
# We install default-libmysqlclient-dev to build the mysql2 gem.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      nodejs \
      yarn \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# 3. Environment Variables
# These settings define the environment for the app and Bundler
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    # We want development gems, so we only exclude production
    BUNDLE_WITHOUT="production" \
    TZ="Etc/UTC"

# 4. Working Directory and Code Copying
WORKDIR /rails

# Use two stages to leverage Docker layer caching
# Copy Gemfile/Lockfile first
COPY Gemfile Gemfile.lock ./

# 5. Install Dependencies
# This runs after system dependencies are installed and uses the development settings
RUN bundle install

# 6. Copy the rest of the application code
COPY . .

# 7. Entrypoint Script Setup
# This script will run migrations and wait for the database at runtime
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

# 8. Permissions Fix (Crucial for development volumes)
# Rails needs to write to log and tmp directories.
# We set permissions broadly to avoid UID/GID conflicts with the host machine.
RUN chmod -R 777 log tmp

# 9. Final Configuration
EXPOSE 3000

# Set the custom entrypoint script
ENTRYPOINT ["docker-entrypoint.sh"]

# Set the default command (will be run by the entrypoint script)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]