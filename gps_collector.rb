require 'pg'
require 'json'
require 'rack'
require 'rgeo/geo_json'

class GpsCollector
  def call(env)
    # TODO: check header 'content-type: application/json' ???
    # TODO: parse after method/path check
    # ignore GET params to process large polygons
    begin
      body = env['rack.input'].read
      body_json = JSON.parse(body)
    rescue JSON::ParserError
      return error_response('Error in data, should be JSON')
    end

    method = env['REQUEST_METHOD']
    path = env['PATH_INFO'][1..-1]

    if (method == 'POST') && (path == 'add_points')
      add_points(body_json)
    elsif (method == 'GET') && (path == 'points_within_radius')
      points_within_radius(body_json)
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

  # Accepts GeoJSON point(s) to be inserted into a database table
  # params: Array of GeoJSON Point objects or Geometry collection

  # TODO: "Array of GeoJSON"
  def add_points(body_json)
    geoms = []

    if body_json.kind_of?(Array)
      body_json.each do |point|
        return error_response('All types in the array must be "Point"') if point['type'] != 'Point'
        return error_response('Coordinates section malformed') if !point['coordinates'].kind_of?(Array)
        return error_response('Coordinates section should contain exactly two numbers') if point['coordinates'].length != 2
        return error_response('Coordinates should be numeric') if point['coordinates'].any? {|c| !c.is_a?(Numeric)} # TODO: kind_of vs is_a

        geoms << RGeo::GeoJSON.decode(point)
      end
    else
      geom = RGeo::GeoJSON.decode(body_json)
      # TODO: RGeo::Cartesian::GeometryCollectionImpl: geo instead of geom???
      return error_response('Params for add_points should be Array of GeoJSON Point objects or Geometry collection') if geom.nil?

      # TODO: assumption, check this
      return error_response('All geometries in the collection must be "Point"') if geom.any? {|c| !c.is_a?(RGeo::Cartesian::PointImpl)}

      geoms = geom.dup
    end


    # TODO: assumption
    return error_response('Should be at least one point in array') if geoms.length.zero?

    params = []
    params_values = []
    geoms.each_with_index do |geom, idx|
      params << "(ST_GeomFromText($#{idx + 1}))"
      params_values << geom
    end
    params_s = params.join(', ')

    DbWrapper.exec_params("INSERT INTO points (point) VALUES #{params_s}", params_values)

    ok_response({})
  end

  # Responds w/GeoJSON point(s) within a radius around a point
  # params: GeoJSON Point and integer radius in feet/meters
  def points_within_radius(body_json)
    # TODO: params check, as it for add_points
    radius = body_json['Radius']

    radius *= 0.3048 if body_json['Radius measure'] == 'feet' # TODO: document this

    geom = RGeo::GeoJSON.decode(body_json['Point'])

    arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1)) <= $2', [geom, radius])
    answer = DbWrapper.parse_selected_points(arr)
    ok_response(answer)
  end

  # Responds w/GeoJSON point(s) within a geographical polygon
  # params: GeoJSON Polygon with no holes
  def points_within_polygon(body_json)
    geom = RGeo::GeoJSON.decode(body_json)

    arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText($1), 0)', [geom])
    answer = DbWrapper.parse_selected_points(arr)

    ok_response(answer)
  end
end