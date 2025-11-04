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
  bundle exec rails db:migrate
fi

# Execute the main container command (i.e., the rails server)
exec "$@"