require './lib/db_wrapper'
require './gps_collector'
use Rack::Reloader
run GpsCollector.new