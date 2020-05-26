# frozen_string_literal: true

require 'rgeo/geo_json'

##
# This class parses params and checks their validity.
#
# Everything around checking a business-logic should be placed here.
class ParamsParser
  # Converts string to JSON with some simple checks. An initial method for all other.
  # @param body [String] string to convert. Typically come from a user via rack.
  # @return [Hash]
  # @raise [ArgumentError] if body param is empty or malformed JSON
  def self.parse_body(body)
    raise ArgumentError, 'Data must be sent in request\'s body' if body.nil?

    begin
      params = JSON.parse(body)
    rescue JSON::ParserError
      raise ArgumentError, 'Error in data, JSON expected'
    end
    params
  end

  # Looks for 'Points' key in the params and checks that it meets the requirements "Array of
  # {GeoJSON Point}[https://tools.ietf.org/html/rfc7946#section-3.1.2] objects or
  # {Geometry collection}[https://tools.ietf.org/html/rfc7946#section-3.1.8]". Returns array of
  # {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl]
  #
  # Calls {add_points_arr} or {add_points_geom} to get the actual result.
  # @param params [Hash] hash that come from {parse_body}
  # @return [Array<RGeo::Cartesian::PointImpl>]
  # @raise [ArgumentError] if no 'Points' key or the result is empty
  def self.add_points(params)
    points_param = params['Points']
    raise ArgumentError, 'Points parameter is required' if points_param.nil?

    # check is it an array or not and call a corresponding method
    points = points_param.is_a?(Array) ? add_points_arr(points_param) : add_points_geom(points_param)

    # Generally, this is an assumption and should be confirmed by a customer.
    # From common sense, it's better to not allow useless empty calls, just to save traffic/resources.
    raise ArgumentError, 'Should be at least one point in the array' if points.length.zero?

    points
  end

  # Converts an array of hashes to array of
  # {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl].
  # @param points_param [Array<Hash>]
  # @return [Array<RGeo::Cartesian::PointImpl>]
  # @raise [ArgumentError] if at least one of elements isn't GeoJSON point.
  def self.add_points_arr(points_param)
    points = []
    points_param.each do |point_param|
      point = RGeo::GeoJSON.decode(point_param)
      raise ArgumentError, 'All elements in the array must be "Point"' unless point.is_a?(RGeo::Cartesian::PointImpl)

      points << point
    end
    points
  end

  # Converts a hash to array of
  # {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl].
  # @param points_param [Hash]
  # @return [Array<RGeo::Cartesian::PointImpl>]
  # @raise [ArgumentError] if at least one of sub-elements isn't GeoJSON point.
  def self.add_points_geom(points_param)
    points = []
    geom = RGeo::GeoJSON.decode(points_param)
    unless geom.is_a?(RGeo::Cartesian::GeometryCollectionImpl)
      raise ArgumentError, 'Points parameter must be an array of GeoJSON Point objects or Geometry collection'
    end

    geom.each do |point|
      unless point.is_a?(RGeo::Cartesian::PointImpl)
        raise ArgumentError, 'All geometries in the collection must be "Point"'
      end

      points << point
    end
    points
  end

  # Extracts from params and checks radius and a center point.
  # Converts a radius to meters if needed.
  #
  # Calls {check_radius} or {check_point} to get the actual result.
  #
  # @param params [Hash] hash that come from {parse_body}
  # @return [Numeric, RGeo::Cartesian::PointImpl, use_spheroid] radius in meters,
  #   {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl]
  #   use_spheroid in terms of PostGIS use_spheroid ST_Distance / ST_DWithin
  def self.points_within_radius(params)
    radius = check_radius(params)
    center_point = check_point(params)
    use_spheroid = check_use_spheroid(params)

    [radius, center_point, use_spheroid]
  end

  # Extracts radius from 'Radius' parameter and converts to meters if needed using 'Radius unit of measure'.
  #
  # @param params [Hash] hash that come from {parse_body}
  # @return [Numeric] radius in meters
  # @raise [ArgumentError] if radius or unit of measure are malformed.
  def self.check_radius(params)
    radius = params['Radius']
    raise ArgumentError, 'Radius parameter is required' if radius.nil?
    raise ArgumentError, 'Radius parameter must be numeric' unless radius.is_a? Numeric
    raise ArgumentError, 'Radius parameter must be non-negative' if radius.negative?

    radius_measure = params['Radius unit of measure']
    if radius_measure
      unless %w[meters feet].include?(radius_measure)
        raise ArgumentError, "'Radius unit of measure' parameter must be 'meters' or 'feet'"
      end

      # convert from feet to meters using a constant from Wiki
      radius *= 0.3048 if radius_measure == 'feet'
    end
    radius
  end

  # Extracts a central point from 'Point' parameter.
  #
  # @param params [Hash] hash that come from {parse_body}
  # @return [RGeo::Cartesian::PointImpl] a central point
  #   {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl].
  # @raise [ArgumentError] if a point is absent or malformed.
  def self.check_point(params)
    raise ArgumentError, 'Point parameter is required' if params['Point'].nil?

    point = RGeo::GeoJSON.decode(params['Point'])
    raise ArgumentError, 'Point parameter is not valid in terms of GeoJSON' if point.nil?
    raise ArgumentError, 'Point parameter must have Point type' unless point.instance_of? RGeo::Cartesian::PointImpl

    point
  end

  # Extracts 'Use spheroid' parameter. Returns true by default
  #
  # @param params [Hash] hash that come from {parse_body}
  # @return [bool]
  # @raise [ArgumentError] if the value is malformed.
  def self.check_use_spheroid(params)
    result = params['Use spheroid']
    result = true if result.nil?
    raise ArgumentError, "'Use spheroid' parameter must be true or false" unless [true, false].include?(result)

    result
  end

  # Extracts a polygon from 'Polygon' parameter.
  #
  # @param params [Hash] hash that come from {parse_body}
  # @return [RGeo::Cartesian::PolygonImpl] a polygon
  #   {RGeo::Cartesian::PolygonImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PolygonImpl].
  # @raise [ArgumentError] if a polygon is absent or malformed.
  def self.points_within_polygon(params)
    raise ArgumentError, 'Polygon parameter is required' if params['Polygon'].nil?

    polygon = RGeo::GeoJSON.decode(params['Polygon'])
    raise ArgumentError, 'Polygon parameter is not valid in terms of GeoJSON' if polygon.nil?
    unless polygon.instance_of? RGeo::Cartesian::PolygonImpl
      raise ArgumentError, 'Polygon parameter must have Polygon type'
    end

    use_spheroid = check_use_spheroid(params)
    [polygon, use_spheroid]
  end
end
