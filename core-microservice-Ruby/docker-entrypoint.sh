#!/bin/bash

set -e

echo "Waiting 5 seconds for database to fully start..."
sleep 5

if [ "$RAILS_ENV" = "development" ]; then
  echo "Running development migrations..."
  bundle exec rails db:migrate
  bundle exec rake chat_worker:start &
fi

exec "$@"
