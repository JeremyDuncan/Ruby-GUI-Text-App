#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Start ngrok in the background
echo "Starting NGROK on port $NGROK_PORT"
ngrok http $NGROK_PORT --domain=$NGROK_DOMAIN &

# Give ngrok a moment to start
sleep 2

echo "Starting SMS APP"
# Start the Ruby application
bundle exec ruby main.rb
