require 'minitest/autorun'
require 'gps_collector.rb'

describe GpsCollector do
  before do
    @gps_collector = GpsCollector.new
    @gps_collector.send(:exec_params, 'TRUNCATE TABLE points') # TODO: test env
  end

  def add_test_points
    data = '
      [
        {"type": "Point", "coordinates": [0, 0]},
        {"type": "Point", "coordinates": [10, 0]},
        {"type": "Point", "coordinates": [20, 0]},
        {"type": "Point", "coordinates": [30, 0]}
      ]
    '
    r1 = test('POST', 'add_points', data)
  end

  # Geometry collection
  def add_test_points_geo
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

  # TODO: Geometry collection
  it 'add points and find them within a radius around a point' do
    add_test_points
    data = '
      {
        "Point" : {"type": "Point", "coordinates": [0, 0]},
        "Radius": 10
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
    add_test_points_geo
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
                ["[{\"type\":\"Point\",\"coordinates\":[10.0,0.0]}]"]]
    _(r2).must_equal expected
  end
end