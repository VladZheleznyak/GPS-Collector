require 'minitest/autorun'
require 'db_wrapper'
require 'gps_collector.rb'

describe GpsCollector do
  before do
    @gps_collector = GpsCollector.new
    DbWrapper.exec_params('TRUNCATE TABLE points') # TODO: test env
  end

  def test(method, endpoint, data)
    rack_input = Minitest::Mock.new
    rack_input.expect :read, data

    env = {
        'REQUEST_METHOD' => method,
        'PATH_INFO' => "/#{endpoint}",
        'rack.input' => rack_input
    }

    @gps_collector.call(env)
  end

  it 'add points and find them within a radius around a point' do
    # latitude: first parameter, -180 to 180 around earth axis
    # longitude: second parameter, -90 to 90 from the equator to the poles
    data = '
      [
        {"type": "Point", "coordinates": [0, 0]},
        {"type": "Point", "coordinates": [10, 0]},
        {"type": "Point", "coordinates": [20, 0]},
        {"type": "Point", "coordinates": [30, 0]}
      ]
    '
    r1 = test('POST', 'add_points', data)
    _(r1.first).must_equal 200

    data = '
      {
        "Point" : {"type": "Point", "coordinates": [0, 0]},
        "Radius": 1113194.90793274
      }
    '
    r2 = test('GET', 'points_within_radius', data)

    # TODO: it's against "the radius values would have to be inclusive", should be two points here
    expected = [200,
                {'Content-Type' => 'application/json'},
                ["[{\"type\":\"Point\",\"coordinates\":[0.0,0.0]},{\"type\":\"Point\",\"coordinates\":[10.0,0.0]}]"]]
    _(r2).must_equal expected
  end

  it 'add points and find them within a radius in feet around a point' do
    data = '
      [
        {"type": "Point", "coordinates": [0, 0]},
        {"type": "Point", "coordinates": [10, 0]},
        {"type": "Point", "coordinates": [20, 0]},
        {"type": "Point", "coordinates": [30, 0]}
      ]
    '
    r1 = test('POST', 'add_points', data)
    _(r1.first).must_equal 200

    data = '
      {
        "Point" : {"type": "Point", "coordinates": [0, 0]},
        "Radius": 1113194.90793274,
        "Radius measure": "feet"
      }
    '
    r2 = test('GET', 'points_within_radius', data)

    # TODO: it's against "the radius values would have to be inclusive", should be two points here
    expected = [200,
                {'Content-Type' => 'application/json'},
                ["[{\"type\":\"Point\",\"coordinates\":[0.0,0.0]}]"]]
    _(r2).must_equal expected
  end

  it 'add points and find them within a geographical polygon' do
    # Geometry collection
    data = '
      {
        "type": "GeometryCollection",
        "geometries": [
           {"type": "Point", "coordinates": [0, 0]},
           {"type": "Point", "coordinates": [10, 0]},
           {"type": "Point", "coordinates": [20, 0]},
           {"type": "Point", "coordinates": [30, 0]}
        ]
      }
    '
    r1 = test('POST', 'add_points', data)
    _(r1.first).must_equal 200

    # https://pasteboard.co/J9ANXOJ.png draw using https://geoman.io/geojson-editor
    # TODO: draw this
    data = '
      {
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
    '
    r2 = test('GET', 'points_within_polygon', data)

    # TODO: it's against "the radius values would have to be inclusive", should be two points here
    expected = [200,
                {'Content-Type' => 'application/json'},
                ["[{\"type\":\"Point\",\"coordinates\":[0.0,0.0]},{\"type\":\"Point\",\"coordinates\":[10.0,0.0]}]"]]
    _(r2).must_equal expected
  end
end