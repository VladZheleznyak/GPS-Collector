class DbWrapper
  def self.exec_params(sql, params_values = [])
    puts 'exec_params=============='
    puts "#{sql}"
    puts "#{params_values}"

    # TODO: multithread?
    @conn ||= PG.connect( host: 'db', dbname: 'gps_collector', user: 'gps_collector', password: 'gps_collector' ) # TODO credentials
    # TODO: DB error processing on connect and exec

    # TODO
    arr = []
    @conn.exec_params(sql, params_values) do |result|
      result.each do |row|
        arr << row
      end
    end
    pp arr
    arr
  end

  def self.parse_selected_points(arr)
    @parser ||= RGeo::WKRep::WKTParser.new

    arr.map do |row|
      point = @parser.parse(row['st_astext'])
      RGeo::GeoJSON.encode(point)
    end
  end
end
