# frozen_string_literal: true

class ParamsParser
  def self.parse_body(body)
    raise ArgumentError.new('Data must be sent in request\'s body') if body.nil?
    begin
      params = JSON.parse(body)
    rescue JSON::ParserError
      raise ArgumentError.new('Error in data, JSON expected')
    end
    params
  end

  # params from the spec: Array of GeoJSON Point objects or Geometry collection
  def self.add_points(params)
    points_param = params['Points']
    raise ArgumentError, 'Points parameter is required' if points_param.nil?

    points = []
    if points_param.is_a?(Array)
      points_param.each do |point|
        raise ArgumentError, 'All types in the array must be "Point"' if point['type'] != 'Point'
        raise ArgumentError, 'Coordinates section malformed' unless point['coordinates'].is_a?(Array)
        if point['coordinates'].length != 2
          raise ArgumentError, 'Coordinates section should contain exactly two numbers'
        end
        raise ArgumentError, 'Coordinates should be numeric' if point['coordinates'].any? { |c| !c.is_a?(Numeric) }

        points << RGeo::GeoJSON.decode(point)
      end
    else
      geom = RGeo::GeoJSON.decode(points_param)
      # TODO: RGeo::Cartesian::GeometryCollectionImpl: geo instead of geom???
      if geom.nil?
        raise ArgumentError, 'Params for add_points should be Array of GeoJSON Point objects or Geometry collection'
      end

      # TODO: assumption, check this
      if geom.any? { |c| !c.is_a?(RGeo::Cartesian::PointImpl) }
        raise ArgumentError, 'All geometries in the collection must be "Point"'
      end

      # TODO: dirty and improper
      geom.each do |element|
        points << element.dup
      end
    end

    # TODO: assumption
    raise ArgumentError, 'Should be at least one point in the array' if points.length.zero?

    points
  end

  # params from the spec: GeoJSON Point and integer radius in feet/meters
  def self.points_within_radius(params)
    # TODO: params check, as it for add_points
    radius = params['Radius']
    raise ArgumentError, 'Radius parameter is required' if radius.nil?
    raise ArgumentError, 'Radius parameter must be numeric' unless radius.is_a? Numeric
    raise ArgumentError, 'Radius parameter must be non-negative' if radius.negative?

    radius_measure = params['Radius measure']
    if radius_measure
      radius *= 0.3048 if radius_measure == 'feet' # TODO: document this
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
end
