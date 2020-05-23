require './lib/db_wrapper'
require './lib/gps_collector_error'
require './lib/params_parser'

class Processor
  # Accepts GeoJSON point(s) to be inserted into a database table
  # params: Array of GeoJSON Point objects or Geometry collection
  def self.add_points(params)
    points = ParamsParser.add_points(params)

    sql_params = []
    sql_params_values = []
    points.each_with_index do |geom, idx|
      sql_params << "(ST_GeomFromText($#{idx + 1}))"
      sql_params_values << geom
    end
    params_s = sql_params.join(', ')

    DbWrapper.exec_params("INSERT INTO points (point) VALUES #{params_s}", sql_params_values)
  end

  # Responds w/GeoJSON point(s) within a radius around a point
  # params: GeoJSON Point and integer radius in feet/meters
  def self.points_within_radius(params)
    radius_meters, center_point = ParamsParser.points_within_radius(params)
    DbWrapper.exec_params('SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1)) <= $2', [center_point, radius_meters])
  end

  # Responds w/GeoJSON point(s) within a geographical polygon
  # params: GeoJSON Polygon with no holes
  def self.points_within_polygon(params)
    polygon = ParamsParser.points_within_polygon(params)
    DbWrapper.exec_params('SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText($1), 0)', [polygon])
  end
end