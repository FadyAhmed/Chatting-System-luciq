#!/bin/bash

set -e

# Wait for the database service to be available
# NOTE: In a real app, use a dedicated wait-for-it script.
# This simple sleep is for reliable local dev setup.
echo "Waiting 5 seconds for database to fully start..."
sleep 5

# Run migrations and database creation only if the environment is development
if [ "$RAILS_ENV" = "development" ]; then
  echo "Running development migrations..."
  # db:migrate will also run db:create if the database doesn't exist
  bundle exec rails db:migrate
  bundle exec rake chat_worker:start &
fi

# Execute the main container command (i.e., the rails server)
# The exec command ensures the application process replaces the script process, 
# receiving signals correctly (like SIGTERM for graceful shutdown).
exec "$@"
