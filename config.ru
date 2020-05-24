# frozen_string_literal: true

require './gps_collector'
use Rack::Reloader
run GpsCollector.new
