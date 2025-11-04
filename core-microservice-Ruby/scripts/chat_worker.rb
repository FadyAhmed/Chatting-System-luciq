#!/usr/bin/env ruby
# frozen_string_literal: true

# Load Rails environment
require_relative "../ config/environment"

# Run the worker
worker = BatchChatWorker.new
worker.run
