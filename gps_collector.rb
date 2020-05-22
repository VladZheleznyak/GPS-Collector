require 'pg'
require 'json'

class GpsCollector
  def call(env)
    # TODO: multithread?
    @conn ||= PG.connect( host: 'db', dbname: 'gps_collector', user: 'gps_collector', password: 'gps_collector' ) # TODO credentials
    # TODO: DB error processing on connect and exec

    req = Rack::Request.new(env)

    # TODO: check header 'content-type: application/json' ???
    # TODO: parse after method/path check
    # ignore GET params to process large polygons
    body = req.body.read
    begin
      body_json = JSON.parse(body)
    rescue JSON::ParserError
      return error_response('Error in data, should be JSON')
    end
    method = env['REQUEST_METHOD']
    path = env['PATH_INFO'][1..-1]

    if (method == 'POST') && (path == 'add_points')
      add_points(body_json)
    elsif (method == 'GET') && (path == 'points_within_radus')
      points_within_radus(body_json)
    elsif (method == 'GET') && (path == 'points_within_polygon')
      points_within_polygon(body_json)
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

  def exec_params(sql, params_s, params_values)
    puts 'exec_params=============='
    puts "#{sql} #{params_s}"
    puts "#{params_values}"

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

  # Accepts GeoJSON point(s) to be inserted into a database table
  # params: Array of GeoJSON Point objects or Geometry collection
  def add_points(body_json)
    pp body_json
    # TODO: Geometry collection
    if !body_json.kind_of?(Array)
      return error_response('Params for add_points should be Array of GeoJSON Point objects or Geometry collection')
    end

    coordinates = []
    body_json.each do |point|
      return error_response('All types in the array must be "Point"') if point['type'] != 'Point'
      return error_response('Coordinates section misformatted') if !point['coordinates'].kind_of?(Array)
      return error_response('Coordinates section should contain exactly two numbers') if point['coordinates'].length != 2
      return error_response('Coordinates should be numeric') if point['coordinates'].any? {|c| !c.is_a?(Numeric)}
      coordinates << point['coordinates']
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
  def points_within_radus(body_json)
    pp body_json

    # TODO: params check, as it for add_points
    x = body_json['Point']['coordinates'][0]
    y = body_json['Point']['coordinates'][0]
    r = body_json['Radius']

    arr = exec_params('SELECT  ST_X(point), ST_Y(point) FROM points WHERE ST_PointInsideCircle(point, $1, $2, $3)', '', [x, y, r])
    answer = arr.map do |row|
      {
          'Point' => {
              'type' => 'Point',
              'coordinates': [row['st_x'], row['st_y']]
          }
      }
    end

    ok_response(answer)
  end

  def points_within_polygon(body_json)
    ok_response({})
  end
end