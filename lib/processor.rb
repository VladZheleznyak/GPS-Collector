# frozen_string_literal: true

require './lib/db_wrapper'
require './lib/params_parser'

##
# This class does the main business-logic via {ParamsParser} and {DbWrapper}.
#
# Each method described in the requirements must be placed here.
class Processor
  ADD_POINT_SQL = '
    INSERT INTO points (point) (
      SELECT ST_MakePoint(cast(v[1] as double precision), cast(v[2] as double precision))
      FROM unnest(regexp_split_to_array($1, \',\')) as q, regexp_split_to_array(q, \' \') as v
    );
  '

  # Accepts GeoJSON point(s) to be inserted into a database table
  # @example
  #   Processor.add_points({'Points' => [{"type" => "Point", "coordinates" => [1, 2]}]})
  # @param params [Hash] Array of GeoJSON Point objects or Geometry collection
  def self.add_points(params)
    # check params
    points = ParamsParser.add_points(params)

    # converts the array of points to a string
    # [POINT(1, 2), POINT(3, 4)] => "1 2,3 4"
    sql_params_values = points.map { |point| "#{point.x} #{point.y}" }.join(',')

    DbWrapper.exec_params(ADD_POINT_SQL, [sql_params_values])
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
    radius_meters, center_point, use_spheroid = ParamsParser.points_within_radius(params)

    # use_spheroid is true by default
    db_result_arr = DbWrapper.exec_params(
      'SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1), $2) <= $3',
      [center_point, use_spheroid, radius_meters]
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
    polygon, use_spheroid = ParamsParser.points_within_polygon(params)
    db_result_arr = DbWrapper.exec_params(
      'SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText($1), 0, $2)',
      [polygon, use_spheroid]
    )
    DbWrapper.parse_selected_points(db_result_arr)
  end
end
