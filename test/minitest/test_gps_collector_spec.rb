# frozen_string_literal: true

require 'minitest/autorun'
require 'db_wrapper'
require 'gps_collector.rb'

describe GpsCollector do
  before do
    @gps_collector = GpsCollector.new
    DbWrapper.exec_params('TRUNCATE TABLE points') # TODO: test env
  end

  def call_rack(method, endpoint, data,
                expected_body, expected_status = 200, expected_headers = { 'Content-Type' => 'application/json' })
    rack_input = Minitest::Mock.new
    rack_input.expect :read, data

    env = {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => "/#{endpoint}",
      'rack.input' => rack_input
    }

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
    it 'adds records from Array of GeoJSON Point objects' do
      data = '
      {
        "Points": [
          {"type": "Point", "coordinates": [1, 2]}
        ]
      }
    '
      call_rack('POST', 'add_points', data, [])
      db_result_arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points')
      _(db_result_arr).must_equal [{ 'st_astext' => 'POINT(1 2)' }]
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
      call_rack('POST', 'add_points', data, [])
      db_result_arr = DbWrapper.exec_params('SELECT ST_AsText(point) FROM points')
      _(db_result_arr).must_equal [{ 'st_astext' => 'POINT(3 4)' }]
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
      call_rack('GET', 'points_within_radius', data,
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
        "Radius measure": "feet"
      }
    '
      # TODO: it's against "the radius values would have to be inclusive", should be two points here
      call_rack('GET', 'points_within_radius', data, [{ 'type' => 'Point', 'coordinates' => [0.0, 0.0] }])
    end
  end

  # `GET` - Responds w/GeoJSON point(s) within a geographical polygon
  # params: GeoJSON Polygon with no holes
  describe 'points_within_polygon' do
    before do
      DbWrapper.exec_params('
        INSERT INTO points (point) VALUES
          (ST_GeomFromText(\'POINT(0 0)\')),
          (ST_GeomFromText(\'POINT(10 0)\')),
          (ST_GeomFromText(\'POINT(20 0)\')),
          (ST_GeomFromText(\'POINT(30 0)\'))
      ')
    end

    it 'responds w/GeoJSON point(s) within a geographical polygon' do
      # https://pasteboard.co/J9ANXOJ.png draw using https://geoman.io/geojson-editor
      # TODO: draw this
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
      call_rack('GET', 'points_within_polygon', data,
                [
                  { 'type' => 'Point', 'coordinates' => [0.0, 0.0] },
                  { 'type' => 'Point', 'coordinates' => [10.0, 0.0] }
                ])
      # TODO: it's against "the radius values would have to be inclusive", should be two points here
    end
  end
end
