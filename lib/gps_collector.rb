# frozen_string_literal: true

require 'rack'
require 'rgeo/geo_json'

require './lib/processor'

##
# This class is the main module for {Rack}[https://github.com/rack/rack/blob/master/SPEC.rdoc].
#
# All web/http/rack logic should be placed here.
class GpsCollector

  # Main rack entry method
  # @param env [Hash] Rack {environment}[https://github.com/rack/rack/blob/master/SPEC.rdoc#label-The+Environment]
  # @return [FixNum, Hash, Array] The {status}[https://github.com/rack/rack/blob/master/SPEC.rdoc#label-The+Status],
  #   the {headers}[https://github.com/rack/rack/blob/master/SPEC.rdoc#label-The+Headers], and
  #   the {body}[https://github.com/rack/rack/blob/master/SPEC.rdoc#label-The+Body].
  def call(env)
    # read data from rack's env and does quick check
    method, path, params = parse_env(env)

    # does the main business-logic
    answer = method_selector(method, path, params)

    # return successful result
    [200, { 'Content-Type' => 'application/json' }, [answer.to_json]]
  rescue ArgumentError, RGeo::Error::RGeoError => e
    # intercept expected exceptions, that are linked with improper user's imput
    # TODO: (prod) in a real life by security reasons we have to intercept all exceptions and hide a stack trace

    [400, { 'Content-Type' => 'application/json' }, [{ 'error' => e.message }.to_json]]
  end

  protected

  # Read data from rack's env and does quick check
  # @param env [Hash] Rack {environment}[https://github.com/rack/rack/blob/master/SPEC.rdoc#label-The+Environment]
  # @return [String, String, Hash] method, path, params
  # @raise [ArgumentError] if Content-type is not 'application/json'
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

  # Selects and calls a corresponding method from {Processor}
  # @param method [String] GET / POST
  # @param path [String] one of add_points / points_within_radius / points_within_polygon
  # @param params [Hash] parameters
  # @raise [ArgumentError] if the method is unknown
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
