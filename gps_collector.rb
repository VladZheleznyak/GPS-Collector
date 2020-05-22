require 'pg'
require 'json'
require 'rack'
require 'rgeo/geo_json'

class GpsCollector
  def call(env)
    # TODO: check header 'content-type: application/json' ???
    # TODO: parse after method/path check
    # ignore GET params to process large polygons
    body = env['rack.input'].read
    begin
      body_json = JSON.parse(body)
      pp body_json
    rescue JSON::ParserError
      return error_response('Error in data, should be JSON')
    end

    method = env['REQUEST_METHOD']
    path = env['PATH_INFO'][1..-1]

    if (method == 'POST') && (path == 'add_points')
      add_points(body, body_json)
    elsif (method == 'GET') && (path == 'points_within_radius')
      points_within_radius(body, body_json)
    elsif (method == 'GET') && (path == 'points_within_polygon')
      points_within_polygon(body)
    else
      error_response("Unknown method and path combination: #{method} #{path}")
    end

    # TODO: exceptions handling
  end

  protected

  def error_response(msg)
    # TODO: 400 to constant
    [400, {'Content-Type' => 'application/json'}, [{'error' => msg}.to_json]]
  end

  def ok_response(answer)
    [200, {'Content-Type' => 'application/json'}, [answer.to_json]]
  end

  def exec_params(sql, params_s = '', params_values = [])
    puts 'exec_params=============='
    puts "#{sql} #{params_s}"
    puts "#{params_values}"

    # TODO: multithread?
    @conn ||= PG.connect( host: 'db', dbname: 'gps_collector', user: 'gps_collector', password: 'gps_collector' ) # TODO credentials
    # TODO: DB error processing on connect and exec

    # TODO
    arr = []
    @conn.exec_params( "#{sql} #{params_s}", params_values) do |result|
      result.each do |row|
        arr << row
      end
    end
    pp arr
    arr
  end

  def parse_selected_points(arr)
    @parser ||= RGeo::WKRep::WKTParser.new

    arr.map do |row|
      point = @parser.parse(row['st_astext'])
      RGeo::GeoJSON.encode(point)
    end
  end

  # Accepts GeoJSON point(s) to be inserted into a database table
  # params: Array of GeoJSON Point objects or Geometry collection

  # TODO: "Array of GeoJSON"
  def add_points(body, body_json)
    coordinates = []

    if body_json.kind_of?(Array)
      body_json.each do |point|
        return error_response('All types in the array must be "Point"') if point['type'] != 'Point'
        return error_response('Coordinates section misformatted') if !point['coordinates'].kind_of?(Array)
        return error_response('Coordinates section should contain exactly two numbers') if point['coordinates'].length != 2
        return error_response('Coordinates should be numeric') if point['coordinates'].any? {|c| !c.is_a?(Numeric)} # TODO: kind_of vs is_a
        coordinates << point['coordinates']
      end
    else
      geom = RGeo::GeoJSON.decode(body)
      # TODO: RGeo::Cartesian::GeometryCollectionImpl: geo instead of geom???
      return error_response('Params for add_points should be Array of GeoJSON Point objects or Geometry collection') if geom.nil?

      # TODO: assumption, check this
      return error_response('All geometries in the collection must be "Point"') if geom.any? {|c| !c.is_a?(RGeo::Cartesian::PointImpl)}

      geom.each do |element|
        coordinates << [element.x, element.y]
      end
    end


    # TODO: assumption
    return error_response('Should be at least one point in array') if coordinates.length.zero?

    # TODO: is the syntax optimal for PG?

    params = []
    params_values = []
    coordinates.each_with_index do |coord, idx|
      # params << "(ST_GeomFromText('POINT($#{idx * 2 + 1} $#{idx * 2 + 2})'))"
      # params_values << coord[0]

      # TODO: SQL-injections here
      x = coord[0].to_s
      y = coord[1].to_s
      params << "(ST_GeomFromText('POINT(#{x} #{y})'))"
    end
    params_s = params.join(', ')

    exec_params('INSERT INTO points (point) VALUES', params_s, params_values)

    ok_response({})
  end

  # Responds w/GeoJSON point(s) within a radius around a point
  # params: GeoJSON Point and integer radius in feet/meters
  def points_within_radius(body, body_json)
    # TODO: params check, as it for add_points
    r = body_json['Radius']
    geom = RGeo::GeoJSON.decode(body_json['Point'])

    # TODO: radius in feet/meters

    arr = exec_params("SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText('#{geom.as_text}')) <= $1", '', [r])
    answer = parse_selected_points(arr)
    ok_response(answer)
  end

  # Responds w/GeoJSON point(s) within a geographical polygon
  # params: GeoJSON Polygon with no holes
  def points_within_polygon(body)
    geom = RGeo::GeoJSON.decode(body)

    arr = exec_params("SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText('#{geom.as_text}'), 0)", '', [])
    answer = parse_selected_points(arr)

    ok_response(answer)
  end
end