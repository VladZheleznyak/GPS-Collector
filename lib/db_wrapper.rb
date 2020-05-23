# frozen_string_literal: true

class DbWrapper
  def self.exec_params(sql, params_values = [])
    # puts 'exec_params=============='
    # puts "#{sql}"
    # puts "#{params_values}"

    # TODO: multithread?
    # TODO: credentials
    @conn ||= PG.connect(host: 'db', dbname: 'gps_collector', user: 'gps_collector', password: 'gps_collector')
    # TODO: DB error processing on connect and exec

    # TODO
    db_result_arr = []
    @conn.exec_params(sql, params_values) do |result|
      result.each do |row|
        db_result_arr << row
      end
    end
    # pp db_result_arr
    db_result_arr
  end

  def self.parse_selected_points(db_result_arr)
    @parser ||= RGeo::WKRep::WKTParser.new

    db_result_arr.map do |row|
      point = @parser.parse(row['st_astext'])
      RGeo::GeoJSON.encode(point)
    end
  end
end
