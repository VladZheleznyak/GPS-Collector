# frozen_string_literal: true

require 'minitest/autorun'
require 'gps_collector.rb'

# Rack::MockRequest and Rack::MockResponse
describe GpsCollector do
  before do
    @gps_collector = GpsCollector.new

    # TODO: (prod) test env
    DbWrapper.exec_params('TRUNCATE TABLE points')
  end

  def prepare_env(method, endpoint, data, content_type = 'application/json')
    rack_input = Minitest::Mock.new
    rack_input.expect :read, data

    result = {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => "/#{endpoint}",
      'rack.input' => rack_input
    }
    result['CONTENT_TYPE'] = content_type if content_type

    result
  end

  def call_rack(env, expected_body, expected_status = 200, expected_headers = { 'Content-Type' => 'application/json' })
    status, headers, body = @gps_collector.call(env)
    _(status).must_equal expected_status
    _(headers).must_equal expected_headers
    _(body.size).must_equal 1
    _(JSON.parse(body.first)).must_equal expected_body
    [status, headers, body]
  end

  # `POST` - Accepts GeoJSON point(s) to be inserted into a database table
  # params: Array of GeoJSON Point objects or Geometry collection
  describe 'add_points' do
    it 'adds one record from Array of GeoJSON Point objects' do
      data = '
        {
          "Points": [
            {"type": "Point", "coordinates": [1, 2]}
          ]
        }
      '

      env = prepare_env('POST', 'add_points', data)
      call_rack(env, [])
      db_result_arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points')
      _(db_result_arr).must_equal [['POINT(1 2)']]
    end

    it 'adds two records from Array of GeoJSON Point objects' do
      data = '
        {
          "Points": [
            {"type": "Point", "coordinates": [1, 2]},
            {"type": "Point", "coordinates": [3, 4]}
          ]
        }
      '
      env = prepare_env('POST', 'add_points', data)
      call_rack(env, [])
      db_result_arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points')
      _(db_result_arr.sort).must_equal [['POINT(1 2)'], ['POINT(3 4)']]
    end

    it 'adds records from Geometry collection' do
      data = '
        {
          "Points": {
            "type": "GeometryCollection",
            "geometries": [
               {"type": "Point", "coordinates": [3, 4]}
            ]
          }
        }
      '
      env = prepare_env('POST', 'add_points', data)
      call_rack(env, [])
      db_result_arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points')
      _(db_result_arr).must_equal [['POINT(3 4)']]
    end
  end

  # `GET` - Responds w/GeoJSON point(s) within a radius around a point
  # params: GeoJSON Point and integer radius in feet/meters
  describe 'points_within_radius' do
    before do
      DbWrapper.exec_params('
        INSERT INTO points (point) VALUES
          (ST_GeomFromText(\'POINT(0 0)\')),
          (ST_GeomFromText(\'POINT(10 0)\')),
          (ST_GeomFromText(\'POINT(20 0)\')),
          (ST_GeomFromText(\'POINT(30 0)\'))
      ')
    end

    it 'responds w/GeoJSON point(s) within a radius around a point' do
      data = '
        {
          "Point" : {"type": "Point", "coordinates": [0, 0]},
          "Radius": 1113194.90793274
        }
      '
      env = prepare_env('GET', 'points_within_radius', data)
      call_rack(env,
                [
                  { 'type' => 'Point', 'coordinates' => [0.0, 0.0] },
                  { 'type' => 'Point', 'coordinates' => [10.0, 0.0] }
                ])
    end

    it 'responds w/GeoJSON point(s) within a radius in feet around a point' do
      data = '
        {
          "Point" : {"type": "Point", "coordinates": [0, 0]},
          "Radius": 1113194.90793274,
          "Radius unit of measure": "feet"
        }
      '
      env = prepare_env('GET', 'points_within_radius', data)
      call_rack(env, [{ 'type' => 'Point', 'coordinates' => [0.0, 0.0] }])
    end
  end

  # `GET` - Responds w/GeoJSON point(s) within a geographical polygon
  # params: GeoJSON Polygon with no holes
  describe 'points_within_polygon' do
    # This is an integration test for checking points inside a polygon.
    it 'responds w/GeoJSON point(s) within a geographical polygon' do
      # Because the calculations done on PG side, we could do test them in whole, without writing a detailed test
      # for each case. Points:
      # A - on a border of the polygon. Should be returned in a result
      # B - inside the polygon. Should be returned in a result
      # C - outside the polygon. The non-convex polygon algorithm is more complex, so should be tested
      # D - outside the polygon.
      # https://gist.github.com/VladZheleznyak/4179b08bd7b9577a7d8f0de3bfe34fe3 via http://geojson.io/
      #  +-------------------------
      #  |                       /
      #  |                    /
      #  |                 /
      #  |              /
      #  A         B    *    C         D
      #  |              \
      #  |                 \
      #  |                    \
      #  |                       \
      #  +-------------------------

      DbWrapper.exec_params('
        INSERT INTO points (point) VALUES
          (ST_GeomFromText(\'POINT(0 0)\')),
          (ST_GeomFromText(\'POINT(10 0)\')),
          (ST_GeomFromText(\'POINT(20 0)\')),
          (ST_GeomFromText(\'POINT(30 0)\'))
      ')

      # "MUST follow the right-hand rule with respect to the area it bounds, i.e., exterior rings are counterclockwise"
      # (c) https://tools.ietf.org/html/rfc7946#section-3.1.6 Polygon
      data = '
        {
          "Polygon": {
            "type": "Polygon",
            "coordinates": [
              [
                [0, -5],
                [25, -5],
                [15, 0],
                [25, 5],
                [0, 5],
                [0, -5]
              ]
            ]
          }
        }
      '
      env = prepare_env('GET', 'points_within_polygon', data)
      call_rack(env,
                [
                  { 'type' => 'Point', 'coordinates' => [0.0, 0.0] },
                  { 'type' => 'Point', 'coordinates' => [10.0, 0.0] }
                ])
    end
  end

  it 'returns an error on unknown combination of method/path' do
    env = prepare_env('POST', 'points_within_polygon', '{}')
    call_rack(env, { 'error' => 'Unknown method and path combination: POST points_within_polygon' }, 400)
  end

  it 'returns an error on improper content_type' do
    env = prepare_env('POST', 'points_within_polygon', '{}', 'text/html')
    call_rack(env, { 'error' => 'Content-type must be \'application/json\', \'text/html\' received' }, 400)
  end
end
