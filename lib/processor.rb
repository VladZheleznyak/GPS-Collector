# frozen_string_literal: true

require './lib/db_wrapper'
require './lib/params_parser'

##
# This class does the main business-logic via {ParamsParser} and {DbWrapper}.
#
# Each method described in the requirements must be placed here.
class Processor
  # Accepts GeoJSON point(s) to be inserted into a database table
  # @example
  #   Processor.add_points({'Points' => [{"type" => "Point", "coordinates" => [1, 2]}]})
  # @param params [Hash] Array of GeoJSON Point objects or Geometry collection
  def self.add_points(params)
    # check params
    points = ParamsParser.add_points(params)
    # generate a variable part of SQL
    params_s, sql_params_values = add_points_prepare_sql(points)

    DbWrapper.exec_params("INSERT INTO points (point) VALUES #{params_s}", sql_params_values)
  end

  # Generates a variable part of SQL
  # @param points [Array<RGeo::Cartesian::PointImpl>] array of
  #   {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl].
  # @return [String, Array] sql text, sql parameters values
  def self.add_points_prepare_sql(points)
    # TODO: this way of passing params looks as not optimal, PG every time executes a new query and couldn't
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

  # Responds w/GeoJSON point(s) within a radius around a point.
  #
  # Uses {ST_Distance}[https://postgis.net/docs/manual-2.5/ST_Distance.html] from PostGIS.
  #
  # ST_Distance use_spheroid is true by default that leads to produce a more accurate result in cost of velocity
  # @example
  #   Processor.points_within_radius({'Point' => {"type" => "Point", "coordinates" => [1, 2]}, 'Radius' => 10, \
  #   'Radius unit of measure' => 'meters'})
  # @param params [Hash] GeoJSON Point and integer radius in feet/meters
  # @return [Array<RGeo::Cartesian::PointImpl>] array of
  #   {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl].
  def self.points_within_radius(params)
    # check params and convert radius to meters
    radius_meters, center_point = ParamsParser.points_within_radius(params)

    # use_spheroid is true by default
    db_result_arr = DbWrapper.exec_params(
      'SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1)) <= $2',
      [center_point, radius_meters]
    )
    DbWrapper.parse_selected_points(db_result_arr)
  end

  # Responds w/GeoJSON point(s) within a geographical polygon
  #
  # Uses {ST_DWithin}[https://postgis.net/docs/manual-2.5/ST_DWithin.html] from PostGIS.
  #
  # @example
  #   Processor.points_within_polygon({"Polygon" => {"type" => "Polygon", "coordinates" => \
  #   [[[0, -5], [25, -5], [15, 0], [25, 5], [0, 5], [0, -5]]]}})
  # ST_DWithin use_spheroid is true by default that leads to produce a more accurate result in cost of velocity
  # @param params [Hash] GeoJSON Polygon with no holes
  # @return [Array<RGeo::Cartesian::PointImpl>] array of
  #   {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl].
  def self.points_within_polygon(params)
    polygon = ParamsParser.points_within_polygon(params)
    db_result_arr = DbWrapper.exec_params(
      'SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText($1), 0)',
      [polygon]
    )
    DbWrapper.parse_selected_points(db_result_arr)
  end
end
