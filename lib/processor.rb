# frozen_string_literal: true

require './lib/db_wrapper'
require './lib/params_parser'

# TODO: tests for each method?
class Processor
  # Accepts GeoJSON point(s) to be inserted into a database table
  # params: Array of GeoJSON Point objects or Geometry collection
  def self.add_points(params)
    points = ParamsParser.add_points(params)
    params_s, sql_params_values = add_points_prepare_sql(points)

    DbWrapper.exec_params("INSERT INTO points (point) VALUES #{params_s}", sql_params_values)
  end

  # Responds w/GeoJSON point(s) within a radius around a point
  # params: GeoJSON Point and integer radius in feet/meters
  def self.points_within_radius(params)
    radius_meters, center_point = ParamsParser.points_within_radius(params)
    db_result_arr = DbWrapper.exec_params(
      'SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1)) <= $2',
      [center_point, radius_meters]
    )
    DbWrapper.parse_selected_points(db_result_arr)
  end

  # Responds w/GeoJSON point(s) within a geographical polygon
  # params: GeoJSON Polygon with no holes
  def self.points_within_polygon(params)
    polygon = ParamsParser.points_within_polygon(params)
    db_result_arr = DbWrapper.exec_params(
      'SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText($1), 0)',
      [polygon]
    )
    DbWrapper.parse_selected_points(db_result_arr)
  end

  def self.add_points_prepare_sql(points)
    # TODO: (prod) this way of passing params a bit suspicious, PG executes a new query every time and couldn't
    # prepare it. Also, each point is wrapped in ST_GeomFromText that adds traffic
    sql_params = []
    sql_params_values = []
    points.each_with_index do |geom, idx|
      sql_params << "(ST_GeomFromText($#{idx + 1}))"
      sql_params_values << geom
    end
    params_s = sql_params.join(', ')

    [params_s, sql_params_values]
  end
end
