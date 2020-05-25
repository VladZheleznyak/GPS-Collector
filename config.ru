# frozen_string_literal: true

require './lib/gps_collector'
use Rack::Reloader

# Disable the multithread execution to keep shared DB connection.
# In a real-life application it's better to setup connection pooling via Mutex.
use Rack::Lock

run GpsCollector.new
