# frozen_string_literal: true

require './gps_collector'
use Rack::Reloader

# TODO: (prod) disable the multithread execution to keep shared DB connection
use Rack::Lock

run GpsCollector.new
