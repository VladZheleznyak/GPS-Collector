class ParamsParser < StandardError
  def self.add_points(params)
    points = []

    if params.kind_of?(Array)
      params.each do |point|
        raise GpsCollectorError.new('All types in the array must be "Point"') if point['type'] != 'Point'
        raise GpsCollectorError.new('Coordinates section malformed') if !point['coordinates'].kind_of?(Array)
        raise GpsCollectorError.new('Coordinates section should contain exactly two numbers') if point['coordinates'].length != 2
        raise GpsCollectorError.new('Coordinates should be numeric') if point['coordinates'].any? {|c| !c.is_a?(Numeric)} # TODO: kind_of vs is_a

        points << RGeo::GeoJSON.decode(point)
      end
    else
      geom = RGeo::GeoJSON.decode(params)
      # TODO: RGeo::Cartesian::GeometryCollectionImpl: geo instead of geom???
      raise GpsCollectorError.new('Params for add_points should be Array of GeoJSON Point objects or Geometry collection') if geom.nil?

      # TODO: assumption, check this
      raise GpsCollectorError.new('All geometries in the collection must be "Point"') if geom.any? {|c| !c.is_a?(RGeo::Cartesian::PointImpl)}

      # TODO: dirty and improper
      geom.each do |element|
        points << element.dup
      end
    end

    # TODO: assumption
    raise GpsCollectorError.new('Should be at least one point in the array') if points.length.zero?

    points
  end

  def self.points_within_radius(params)
    # TODO: params check, as it for add_points
    radius = params['Radius']

    radius *= 0.3048 if params['Radius measure'] == 'feet' # TODO: document this

    center_point = RGeo::GeoJSON.decode(params['Point'])

    [radius, center_point]
  end

  def self.points_within_polygon(params)
    RGeo::GeoJSON.decode(params)
  end
end