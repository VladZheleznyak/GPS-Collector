# frozen_string_literal: true

require 'pg'

class DbWrapper
  def self.exec_params(sql, params_values = [])
    # puts 'exec_params=============='
    # puts "#{sql}"
    # puts "#{params_values}"

    # TODO: (prod) credentials
    @conn ||= PG.connect(host: 'db', dbname: 'gps_collector', user: 'gps_collector', password: 'gps_collector')
    # TODO: (prod) DB error processing on connect and exec

    result = @conn.exec_params(sql, params_values)
    result.values
  end

  def self.parse_selected_points(db_result_arr)
    @parser ||= RGeo::WKRep::WKTParser.new

    db_result_arr.map do |row|
      point = @parser.parse(row.first)
      RGeo::GeoJSON.encode(point)
    end
  end
end
