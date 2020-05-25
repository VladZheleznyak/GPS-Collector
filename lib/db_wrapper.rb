# frozen_string_literal: true

require 'pg'

##
# This class represents a DB wrapper. It connects to a DB, executes queries and converts a result if needed.
#
# Everything DB-related and DB-specific should be encapsulated here.
#
# @todo The class isn't threadsafe. At the moment the multithreading disabled by calling Rack::Lock at config.ru.
#   To add the support, connection pooling via Mutex is required
class DbWrapper
  ##
  # Sends SQL query request specified by sql to PostgreSQL using placeholders for parameters.
  # @param sql [String] SQL to execute
  # @param params [Array] is an array of the bind parameters for the SQL query
  # @return [Array] array of rows/columns returned by DB server. Should be parsed via {parse_selected_points}
  # @example
  #   DbWrapper.exec_params('TRUNCATE TABLE points')
  #   => []
  #   DbWrapper.exec_params('SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1))' + \
  #   '<= $2', ['POINT (0.01621 0.57422)', 17000000])
  #   => [["POINT(0 0)"], ["POINT(10 0)"], ["POINT(20 0)"], ["POINT(30 0)"]]

  def self.exec_params(sql, params = [])
    # TODO: move credentials to config
    # At the moment the multithreading disabled by calling Rack::Lock at config.ru
    @conn ||= PG.connect(host: 'db', dbname: 'gps_collector', user: 'gps_collector', password: 'gps_collector')

    result = @conn.exec_params(sql, params)
    result.values
  end

  # Converts array of rows/columns that we got from exec_params to array of
  # {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl]
  #
  # @param db_result_arr [String] Result of {exec_params}
  # @return [Array<RGeo::Cartesian::PointImpl>] array of
  #   {RGeo::Cartesian::PointImpl}[https://www.rubydoc.info/gems/rgeo/RGeo/Cartesian/PointImpl]
  def self.parse_selected_points(db_result_arr)
    @parser ||= RGeo::WKRep::WKTParser.new

    db_result_arr.map do |row|
      point = @parser.parse(row.first)
      RGeo::GeoJSON.encode(point)
    end
  end
end
