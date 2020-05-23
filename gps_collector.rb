require 'pg'
require 'json'
require 'rack'
require 'rgeo/geo_json'

require './lib/gps_collector_error'
require './lib/processor'

class GpsCollector
  def call(env)
    method, path, params = parse_env(env)

    if (method == 'POST') && (path == 'add_points')
      answer = Processor.add_points(params)
    elsif (method == 'GET') && (path == 'points_within_radius')
      answer = Processor.points_within_radius(params)
    elsif (method == 'GET') && (path == 'points_within_polygon')
      answer = Processor.points_within_polygon(params)
    else
      # TODO: test
      raise GpsCollectorError.new("Unknown method and path combination: #{method} #{path}")
    end

    [200, {'Content-Type' => 'application/json'}, [answer.to_json]]
  rescue GpsCollectorError, ArgumentError, RGeo::Error::RGeoError => e
    [400, {'Content-Type' => 'application/json'}, [{'error' => e.message}.to_json]]
    # TODO: write a comment about exceptions handling like DB. At prod they should be hidden
  end

  protected

  def parse_env(env)
    # TODO: check header 'content-type: application/json' ???
    # TODO: parse after method/path check
    # ignore GET params to process large polygons
    begin
      body = env['rack.input'].read
      params = JSON.parse(body)
    rescue JSON::ParserError
      raise GpsCollectorError.new('Error in data, should be JSON')
    end

    method = env['REQUEST_METHOD']
    path = env['PATH_INFO'][1..-1]

    [method, path, params]
  end
end