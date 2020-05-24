# frozen_string_literal: true

class ParamsParser
  def self.parse_body(body)
    raise ArgumentError, 'Data must be sent in request\'s body' if body.nil?

    begin
      params = JSON.parse(body)
    rescue JSON::ParserError
      raise ArgumentError, 'Error in data, JSON expected'
    end
    params
  end

  # params from the spec: Array of GeoJSON Point objects or Geometry collection
  def self.add_points(params)
    points_param = params['Points']
    raise ArgumentError, 'Points parameter is required' if points_param.nil?

    # check is it an array or not and call a corresponding method
    points = points_param.is_a?(Array) ? add_points_arr(points_param) : add_points_geom(points_param)

    raise ArgumentError, 'Should be at least one point in the array' if points.length.zero?

    points
  end

  # params from the spec: GeoJSON Point and integer radius in feet/meters
  def self.points_within_radius(params)
    radius = params['Radius']
    raise ArgumentError, 'Radius parameter is required' if radius.nil?
    raise ArgumentError, 'Radius parameter must be numeric' unless radius.is_a? Numeric
    raise ArgumentError, 'Radius parameter must be non-negative' if radius.negative?

    radius_measure = params['Radius measure']
    if radius_measure
      radius *= 0.3048 if radius_measure == 'feet'
      unless %w[meters feet].include?(radius_measure)
        raise ArgumentError, '"Radius measure" parameter must be "meters" or "feet"'
      end
    end

    raise ArgumentError, 'Polygon parameter is required' if params['Point'].nil?

    center_point = RGeo::GeoJSON.decode(params['Point'])
    raise ArgumentError, 'Polygon parameter is not valid in terms of GeoJSON' if center_point.nil?
    unless center_point.instance_of? RGeo::Cartesian::PointImpl
      raise ArgumentError, 'Polygon parameter must have Polygon type'
    end

    [radius, center_point]
  end

  # params from the spec: GeoJSON Polygon with no holes
  def self.points_within_polygon(params)
    raise ArgumentError, 'Polygon parameter is required' if params['Polygon'].nil?

    polygon = RGeo::GeoJSON.decode(params['Polygon'])
    raise ArgumentError, 'Polygon parameter is not valid in terms of GeoJSON' if polygon.nil?
    unless polygon.instance_of? RGeo::Cartesian::PolygonImpl
      raise ArgumentError, 'Polygon parameter must have Polygon type'
    end

    polygon
  end

  def self.add_points_arr(points_param)
    points = []
    points_param.each do |point_param|
      point = RGeo::GeoJSON.decode(point_param)
      raise ArgumentError, 'All elements in the array must be "Point"' unless point.is_a?(RGeo::Cartesian::PointImpl)

      points << point
    end
    points
  end

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
end
