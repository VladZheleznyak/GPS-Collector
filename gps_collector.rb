# frozen_string_literal: true

require 'rack'
require 'rgeo/geo_json'

require './lib/processor'

class GpsCollector
  def call(env)
    method, path, params = parse_env(env)

    answer = method_selector(method, path, params)

    [200, { 'Content-Type' => 'application/json' }, [answer.to_json]]
  rescue ArgumentError, RGeo::Error::RGeoError => e
    # intercept expected exceptions, that are linked with improper user's imput
    # TODO: (prod) in a real life by security reasons we have to intercept all exceptions and hide a stack trace

    [400, { 'Content-Type' => 'application/json' }, [{ 'error' => e.message }.to_json]]
  end

  protected

  def parse_env(env)
    ct = env['CONTENT_TYPE']
    # potentially, it's possible to check the value case insensitive. But this is something that is hard to check in
    # the future to keep compatibility. And this is against RFC
    # https://stackoverflow.com/questions/7718476/are-http-headers-content-type-c-case-sensitive
    raise ArgumentError, "Content-type must be 'application/json', '#{ct}' received" if ct && (ct != 'application/json')

    body = env['rack.input'].read
    params = ParamsParser.parse_body(body)

    method = env['REQUEST_METHOD']
    path = env['PATH_INFO'][1..-1]

    [method, path, params]
  end

  def method_selector(method, path, params)
    if (method == 'POST') && (path == 'add_points')
      answer = Processor.add_points(params)
    elsif (method == 'GET') && (path == 'points_within_radius')
      answer = Processor.points_within_radius(params)
    elsif (method == 'GET') && (path == 'points_within_polygon')
      answer = Processor.points_within_polygon(params)
    else
      raise ArgumentError, "Unknown method and path combination: #{method} #{path}"
    end
    answer
  end
end
